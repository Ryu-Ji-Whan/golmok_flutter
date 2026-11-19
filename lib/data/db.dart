import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'geo.dart';
import 'models.dart';

/// 폰 안 데이터베이스 (SQLite). 지금 3판 (3: spots.from_name)
/// 나중에 서버(예: Supabase)를 붙일 때도 같은 표 구조를 쓰면 된다 → supabase/schema.sql
class AppDb {
  AppDb._(this._db);
  final Database _db;

  static Future<AppDb> open() async {
    final path = p.join(await getDatabasesPath(), 'golmok.db');
    final db = await openDatabase(path, version: 3, onUpgrade: (db, from, to) async {
      // 2: 밝힌 칸에 '그때 있던 동네'(area)와 밝힌 시각(at)을 같이 저장
      if (from < 2) {
        await db.execute('ALTER TABLE explored ADD COLUMN area TEXT');
        await db.execute('ALTER TABLE explored ADD COLUMN at INTEGER');
      }
      // 3: 친구에게 받은 기록이면 보낸 사람 닉네임
      if (from < 3) await db.execute('ALTER TABLE spots ADD COLUMN from_name TEXT');
    }, onCreate: (db, _) async {
      final b = db.batch();
      b.execute('''CREATE TABLE profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        nickname TEXT NOT NULL, character_id TEXT NOT NULL, area_name TEXT NOT NULL,
        provider TEXT NOT NULL, marketing INTEGER NOT NULL, joined_at INTEGER NOT NULL,
        logged_in INTEGER NOT NULL)''');
      b.execute('''CREATE TABLE walks (
        id TEXT PRIMARY KEY, started_at INTEGER NOT NULL, ended_at INTEGER,
        distance_m REAL NOT NULL DEFAULT 0, new_cells INTEGER NOT NULL DEFAULT 0)''');
      b.execute('''CREATE TABLE walk_points (
        walk_id TEXT NOT NULL REFERENCES walks(id) ON DELETE CASCADE,
        seq INTEGER NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL,
        PRIMARY KEY (walk_id, seq))''');
      b.execute('''CREATE TABLE spots (
        id TEXT PRIMARY KEY, walk_id TEXT, lat REAL NOT NULL, lng REAL NOT NULL,
        sticker_id TEXT NOT NULL, title TEXT NOT NULL, memo TEXT NOT NULL, photo TEXT,
        visibility TEXT NOT NULL, shared INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, from_name TEXT)''');
      b.execute('CREATE TABLE explored (cell TEXT PRIMARY KEY, area TEXT, at INTEGER)');
      // kind: owned(가진 스티커) / stamp(스탬프) / reward(받은 보상) / store(방문한 가게)
      b.execute('CREATE TABLE marks (kind TEXT NOT NULL, id TEXT NOT NULL, at INTEGER NOT NULL, PRIMARY KEY (kind, id))');
      b.execute('''CREATE TABLE coupons (
        id TEXT PRIMARY KEY, store_id TEXT NOT NULL, title TEXT NOT NULL,
        issued_at INTEGER NOT NULL, used_at INTEGER)''');
      b.execute('CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)');
      await b.commit(noResult: true);
    });
    return AppDb._(db);
  }

  // ── 읽기 ──
  Future<Profile?> profile() async {
    final rows = await _db.query('profile', where: 'id = 1');
    return rows.isEmpty ? null : Profile.fromRow(rows.first);
  }

  Future<List<Walk>> walks() async {
    final rows = await _db.query('walks', orderBy: 'started_at DESC');
    final pts = await _db.query('walk_points', orderBy: 'walk_id, seq');
    final byWalk = <String, List<LatLng>>{};
    for (final r in pts) {
      byWalk.putIfAbsent(r['walk_id'] as String, () => []).add(LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()));
    }
    return rows.map((r) => Walk.fromRow(r, byWalk[r['id']] ?? [])).toList();
  }

  Future<List<Spot>> spots() async =>
      (await _db.query('spots', orderBy: 'created_at DESC')).map(Spot.fromRow).toList();

  Future<Set<String>> explored() async =>
      (await _db.query('explored')).map((r) => r['cell'] as String).toSet();

  Future<Set<String>> marks(String kind) async =>
      (await _db.query('marks', where: 'kind = ?', whereArgs: [kind])).map((r) => r['id'] as String).toSet();

  Future<List<Coupon>> coupons() async =>
      (await _db.query('coupons', orderBy: 'issued_at DESC')).map(Coupon.fromRow).toList();

  Future<String?> kv(String k) async {
    final rows = await _db.query('kv', where: 'k = ?', whereArgs: [k]);
    return rows.isEmpty ? null : rows.first['v'] as String;
  }

  // ── 쓰기 ──
  Future<void> saveProfile(Profile p) =>
      _db.insert('profile', p.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveWalk(Walk w) => _db.insert('walks', w.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> addPoint(String walkId, int seq, LatLng p) => _db.insert(
      'walk_points', {'walk_id': walkId, 'seq': seq, 'lat': p.lat, 'lng': p.lng},
      conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> addPoints(String walkId, List<LatLng> path) async {
    final b = _db.batch();
    for (var i = 0; i < path.length; i++) {
      b.insert('walk_points', {'walk_id': walkId, 'seq': i + 1, 'lat': path[i].lat, 'lng': path[i].lng},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await b.commit(noResult: true);
  }

  Future<void> saveSpot(Spot s) => _db.insert('spots', s.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteSpot(String id) => _db.delete('spots', where: 'id = ?', whereArgs: [id]);

  /// 새로 밝힌 칸 저장. [area]는 그 칸을 밝힐 때 있던 동네 (모르면 null, 나중에 [tagCells]로 채움)
  Future<void> addExplored(Iterable<String> cells, {String? area}) async {
    final at = DateTime.now().millisecondsSinceEpoch;
    final b = _db.batch();
    for (final c in cells) {
      b.insert('explored', {'cell': c, 'area': area, 'at': at}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await b.commit(noResult: true);
  }

  /// 동네를 모른 채 저장한 칸에 동네 이름 채우기
  Future<void> tagCells(Iterable<String> cells, String area) async {
    final b = _db.batch();
    for (final c in cells) {
      b.update('explored', {'area': area}, where: 'cell = ? AND area IS NULL', whereArgs: [c]);
    }
    await b.commit(noResult: true);
  }

  /// 밝힌 칸 전체를 바꾼다 (칸 크기를 바꿀 때)
  Future<void> replaceExplored(Set<String> cells) async {
    final b = _db.batch();
    b.delete('explored');
    for (final c in cells) {
      b.insert('explored', {'cell': c}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await b.commit(noResult: true);
  }

  Future<void> addMarks(String kind, Iterable<String> ids) async {
    final at = DateTime.now().millisecondsSinceEpoch;
    final b = _db.batch();
    for (final id in ids) {
      b.insert('marks', {'kind': kind, 'id': id, 'at': at}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await b.commit(noResult: true);
  }

  Future<void> saveCoupon(Coupon c) => _db.insert('coupons', c.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> setKv(String k, String v) => _db.insert('kv', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  /// 데모 데이터 초기화: 모든 표를 비운다.
  Future<void> wipe() async {
    final b = _db.batch();
    for (final t in ['profile', 'walks', 'walk_points', 'spots', 'explored', 'marks', 'coupons', 'kv']) {
      b.delete(t);
    }
    await b.commit(noResult: true);
  }
}
