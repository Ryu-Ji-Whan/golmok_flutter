import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'geo.dart';
import 'models.dart';

/// 서버(Supabase)에서 받아 온 내 데이터 전체
class RemoteData {
  RemoteData({this.profile, required this.walks, required this.spots, required this.explored, required this.marks, required this.coupons});
  final Profile? profile;
  final List<Walk> walks;
  final List<Spot> spots;
  final Set<String> explored;
  final Map<String, Set<String>> marks;
  final List<Coupon> coupons;
}

/// 서버 피드 글 한 개
class RemoteFeedPost {
  RemoteFeedPost(this.id, this.nickname, this.character, this.area, this.sticker, this.title, this.memo, this.createdAt);
  final String id, nickname, character, area, sticker, title, memo;
  final DateTime createdAt;
}

/// 서버 리더보드 한 줄
class RemoteRank {
  RemoteRank(this.nickname, this.character, this.cells);
  final String nickname, character;
  final int cells;
}

String _iso(DateTime t) => t.toUtc().toIso8601String();
DateTime _dt(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dtOrNull(Object? v) => v == null ? null : _dt(v);

/// 서버와 주고받는 일. 로그인 안 했거나 인터넷이 없으면 조용히 건너뛴다(폰 DB가 먼저 저장하므로).
class Remote {
  static bool _ready = false;

  static Future<void> init() async {
    if (!supabaseConfigured) return;
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static bool get available => _ready;
  static SupabaseClient get _c => Supabase.instance.client;
  static User? get user => _ready ? _c.auth.currentUser : null;
  static bool get signedIn => user != null;
  static String? get email => user?.email;

  // ── 로그인 ──
  /// 성공하면 null, 실패하면 보여 줄 문장
  static Future<String?> signUp(String email, String password) async {
    if (!_ready) return '서버 연결 설정이 아직 없어요';
    try {
      final r = await _c.auth.signUp(email: email, password: password);
      if (r.session == null) return '가입 확인 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인해 주세요';
      return null;
    } on AuthException catch (e) {
      return _authMessage(e.message);
    } catch (_) {
      return '인터넷 연결을 확인해 주세요';
    }
  }

  static Future<String?> signIn(String email, String password) async {
    if (!_ready) return '서버 연결 설정이 아직 없어요';
    try {
      await _c.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return _authMessage(e.message);
    } catch (_) {
      return '인터넷 연결을 확인해 주세요';
    }
  }

  static Future<void> signOut() async {
    await flushExplored();
    if (!signedIn) return;
    try {
      await _c.auth.signOut();
    } catch (_) {}
  }

  static String _authMessage(String m) {
    final s = m.toLowerCase();
    if (s.contains('invalid login')) return '이메일이나 비밀번호가 맞지 않아요';
    if (s.contains('already registered') || s.contains('already been registered')) return '이미 가입한 이메일이에요. 로그인해 주세요';
    if (s.contains('password')) return '비밀번호는 6자 이상으로 해 주세요';
    if (s.contains('email')) return '이메일 주소를 확인해 주세요';
    return m;
  }

  /// 서버에서 닉네임이 이미 쓰이는지. 확인할 수 없으면 false.
  static Future<bool> nicknameTaken(String name) async {
    if (!_ready) return false;
    try {
      final r = await _c.rpc('nickname_taken', params: {'name': name});
      return r == true;
    } catch (_) {
      return false;
    }
  }

  // ── 올리기 (실패해도 앱은 계속) ──
  static Future<void> _try(Future<void> Function() f) async {
    if (!signedIn) return;
    try {
      await f();
    } catch (_) {}
  }

  /// 닉네임이 겹치면 '이미 쓰고 있는 닉네임이에요', 성공·오프라인이면 null
  static Future<String?> saveProfile(Profile p) async {
    if (!signedIn) return null;
    try {
      await _c.from('profiles').upsert({
        'user_id': user!.id,
        'nickname': p.nickname,
        'character_id': p.characterId,
        'area_name': p.areaName,
        'provider': p.provider,
        'marketing': p.marketing,
        'joined_at': _iso(p.joinedAt),
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return '이미 쓰고 있는 닉네임이에요';
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveWalk(Walk w) => _try(() => _c.from('walks').upsert({
        'id': w.id,
        'started_at': _iso(w.startedAt),
        'ended_at': w.endedAt == null ? null : _iso(w.endedAt!),
        'distance_m': w.distanceM,
        'new_cells': w.newCells,
        'path': w.path.map((p) => p.toLngLat()).toList(),
      }));

  static Future<void> saveSpot(Spot s) => _try(() => _c.from('spots').upsert({
        'id': s.id,
        'walk_id': s.walkId,
        'lat': s.lat,
        'lng': s.lng,
        'sticker_id': s.stickerId,
        'title': s.title,
        'memo': s.memo,
        'photo': s.photo,
        'visibility': s.visibility.name,
        'shared': s.shared,
        'created_at': _iso(s.createdAt),
      }));

  static Future<void> deleteSpot(String id) => _try(() => _c.from('spots').delete().eq('id', id));

  static Future<void> addMarks(String kind, Iterable<String> ids) {
    final rows = [for (final id in ids) {'kind': kind, 'id': id}];
    if (rows.isEmpty) return Future.value();
    return _try(() => _c.from('marks').upsert(rows, ignoreDuplicates: true));
  }

  static Future<void> saveCoupon(Coupon c) => _try(() => _c.from('coupons').upsert({
        'id': c.id,
        'store_id': c.storeId,
        'title': c.title,
        'issued_at': _iso(c.issuedAt),
        'used_at': c.usedAt == null ? null : _iso(c.usedAt!),
      }));

  // 밝힌 칸은 걸을 때마다 생기므로 모아 뒀다가 20초마다 한 번에 올린다.
  static final Set<String> _pendingCells = {};
  static Timer? _flushTimer;

  static void addExplored(Iterable<String> cells) {
    if (!signedIn) return;
    _pendingCells.addAll(cells);
    _flushTimer ??= Timer(const Duration(seconds: 20), flushExplored);
  }

  static Future<void> flushExplored() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingCells.isEmpty) return;
    final rows = [for (final c in _pendingCells) {'cell': c}];
    _pendingCells.clear();
    await _try(() => _c.from('explored').upsert(rows, ignoreDuplicates: true));
  }

  /// 서버의 내 밝힌 칸을 통째로 바꾼다 (칸 크기를 바꿀 때)
  static Future<void> replaceExplored(Set<String> cells) => _try(() async {
        await _c.from('explored').delete().eq('user_id', user!.id);
        final list = cells.toList();
        for (var i = 0; i < list.length; i += 500) {
          await _c.from('explored').upsert([for (final c in list.skip(i).take(500)) {'cell': c}], ignoreDuplicates: true);
        }
      });

  /// 처음 로그인할 때 이 폰에 있던 기록을 한꺼번에 올린다.
  static Future<void> uploadAll({
    required List<Walk> walks,
    required List<Spot> spots,
    required Set<String> explored,
    required Map<String, Set<String>> marks,
    required List<Coupon> coupons,
  }) async {
    for (final w in walks) {
      await saveWalk(w);
    }
    for (final s in spots) {
      await saveSpot(s);
    }
    final cells = explored.toList();
    for (var i = 0; i < cells.length; i += 500) {
      final chunk = [for (final c in cells.skip(i).take(500)) {'cell': c}];
      await _try(() => _c.from('explored').upsert(chunk, ignoreDuplicates: true));
    }
    for (final e in marks.entries) {
      await addMarks(e.key, e.value);
    }
    for (final c in coupons) {
      await saveCoupon(c);
    }
  }

  // ── 받아 오기 ──
  static Future<List<Map<String, dynamic>>> _all(String table, {String order = 'id'}) async {
    // Supabase는 한 번에 최대 1000줄을 주므로 나눠서 받는다.
    final out = <Map<String, dynamic>>[];
    for (var from = 0;; from += 1000) {
      final page = await _c.from(table).select().order(order).range(from, from + 999);
      out.addAll(page);
      if (page.length < 1000) break;
    }
    return out;
  }

  /// 내 서버 데이터 전체. 실패하면 null.
  static Future<RemoteData?> fetchAll() async {
    if (!signedIn) return null;
    try {
      final uid = user!.id;
      final prof = await _c.from('profiles').select().eq('user_id', uid).maybeSingle();
      final walks = await _all('walks', order: 'started_at');
      final spots = await _all('spots', order: 'created_at');
      final cells = await _all('explored', order: 'cell');
      final marks = await _all('marks', order: 'id');
      final coupons = await _all('coupons', order: 'issued_at');
      final markMap = <String, Set<String>>{};
      for (final m in marks) {
        markMap.putIfAbsent(m['kind'] as String, () => {}).add(m['id'] as String);
      }
      return RemoteData(
        profile: prof == null
            ? null
            : Profile(
                nickname: prof['nickname'] as String,
                characterId: prof['character_id'] as String,
                areaName: prof['area_name'] as String,
                provider: prof['provider'] as String,
                marketing: prof['marketing'] as bool,
                joinedAt: _dt(prof['joined_at']),
              ),
        walks: [
          for (final w in walks.reversed)
            Walk(
              id: w['id'] as String,
              startedAt: _dt(w['started_at']),
              endedAt: _dtOrNull(w['ended_at']),
              distanceM: (w['distance_m'] as num).toDouble(),
              newCells: w['new_cells'] as int,
              path: [
                for (final p in (w['path'] as List))
                  LatLng(((p as List)[1] as num).toDouble(), (p[0] as num).toDouble()),
              ],
            ),
        ],
        spots: [
          for (final s in spots.reversed)
            Spot(
              id: s['id'] as String,
              walkId: s['walk_id'] as String?,
              lat: (s['lat'] as num).toDouble(),
              lng: (s['lng'] as num).toDouble(),
              stickerId: s['sticker_id'] as String,
              title: s['title'] as String,
              memo: s['memo'] as String,
              photo: s['photo'] as String?,
              visibility: SpotVisibility.values.firstWhere((v) => v.name == s['visibility'], orElse: () => SpotVisibility.all),
              shared: s['shared'] as bool,
              createdAt: _dt(s['created_at']),
            ),
        ],
        explored: {for (final c in cells) c['cell'] as String},
        marks: markMap,
        coupons: [
          for (final c in coupons.reversed)
            Coupon(
              id: c['id'] as String,
              storeId: c['store_id'] as String,
              title: c['title'] as String,
              issuedAt: _dt(c['issued_at']),
              usedAt: _dtOrNull(c['used_at']),
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<RemoteFeedPost>> feed() async {
    if (!signedIn) return [];
    try {
      final rows = await _c.from('public_feed').select();
      return [
        for (final r in rows)
          RemoteFeedPost(
            r['id'] as String,
            r['nickname'] as String,
            r['character_id'] as String,
            r['area_name'] as String,
            r['sticker_id'] as String,
            r['title'] as String,
            (r['memo'] as String?) ?? '',
            _dt(r['created_at']),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<List<RemoteRank>> leaderboard(String area) async {
    if (!signedIn) return [];
    try {
      final rows = await _c.from('weekly_leaderboard').select().eq('area_name', area).order('cells', ascending: false).limit(50);
      return [for (final r in rows) RemoteRank(r['nickname'] as String, r['character_id'] as String, (r['cells'] as num).toInt())];
    } catch (_) {
      return [];
    }
  }
}
