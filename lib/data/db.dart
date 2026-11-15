import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'geo.dart';
import 'models.dart';

/// 폰 안 데이터베이스 (SQLite).
/// 나중에 서버(예: Supabase)를 붙일 때도 같은 표 구조를 쓰면 된다 → supabase/schema.sql
class AppDb {
  AppDb._(this._db);
  final Database _db;

  static Future<AppDb> open() async {
    final path = p.join(await getDatabasesPath(), 'golmok.db');
    final db = await openDatabase(path, version: 1, onCreate: (db, _) async {
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
        visibility TEXT NOT NULL, shared INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)''');
      b.execute('CREATE TABLE explored (cell TEXT PRIMARY KEY)');
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

  Future<void> addExplored(Iterable<String> cells) async {
    final b = _db.batch();
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
