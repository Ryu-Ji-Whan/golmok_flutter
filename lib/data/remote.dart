import 'dart:async';
import 'dart:convert';
import 'dart:io' show ContentType, HttpClient;

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

/// 회원가입 결과: 바로 로그인됨 / 인증 메일을 확인해야 함
enum SignUpResult { signedIn, checkEmail }

/// 서버 피드 글 한 개
class RemoteFeedPost {
  RemoteFeedPost(this.id, this.nickname, this.character, this.area, this.sticker, this.title, this.memo, this.createdAt);
  final String id, nickname, character, area, sticker, title, memo;
  final DateTime createdAt;
}

/// 서버 리더보드 한 줄
class RemoteRank {
  RemoteRank(this.nickname, this.character, this.cells, {this.isMe = false});
  final String nickname, character;
  final int cells;
  final bool isMe;
}

/// 내가 걸은 동네 하나와 그 동네에서 내 순위
class MyArea {
  MyArea(this.area, this.cells, this.rank, this.people);
  final String area;
  final int cells, rank, people;
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

  // ── 아이디 로그인 · 회원가입 ──
  /// 아이디 규칙: 영어 소문자·숫자·밑줄 4~20자 (서버 supabase/migrations/002_username_login.sql 과 같음)
  static final usernamePattern = RegExp(r'^[a-z0-9_]{4,20}$');

  /// 아이디 · 비밀번호 · 이메일로 가입한다. 이메일로 인증 메일이 간다.
  /// 성공: (signedIn: 바로 로그인됨 / checkEmail: 인증 메일 확인 필요, null), 실패: (null, 보여 줄 문장)
  static Future<(SignUpResult?, String?)> signUp({required String username, required String email, required String password}) async {
    if (!_ready) return (null, '서버 연결 설정이 아직 없어요');
    try {
      // 인증 메일 링크를 누르면 GitHub Pages의 "인증 완료" 화면이 열린다 (docs/auth/index.html)
      final r = await _c.auth.signUp(
        email: email,
        password: password,
        data: {'username': username.toLowerCase()},
        emailRedirectTo: emailConfirmedUrl,
      );
      // 이미 가입한 이메일이면 Supabase는 오류 대신 빈 계정을 돌려준다
      if (r.user != null && (r.user!.identities?.isEmpty ?? false)) {
        return (null, '이미 가입한 이메일이에요. 아이디로 로그인해 주세요');
      }
      return (r.session == null ? SignUpResult.checkEmail : SignUpResult.signedIn, null);
    } on AuthException catch (e) {
      // 아이디가 겹치면 서버 트리거가 막아서 "Database error saving new user"가 온다
      if (e.message.toLowerCase().contains('database error')) return (null, '이미 쓰고 있는 아이디예요');
      return (null, _authMessage(e.message));
    } catch (_) {
      return (null, '인터넷 연결을 확인해 주세요');
    }
  }

  /// 아이디(또는 이메일) + 비밀번호로 로그인. 성공하면 null, 실패하면 보여 줄 문장
  static Future<String?> signIn(String id, String password) async {
    if (!_ready) return '서버 연결 설정이 아직 없어요';
    final login = id.trim();
    try {
      if (login.contains('@')) {
        await _c.auth.signInWithPassword(email: login, password: password);
        return null;
      }
      // 아이디 로그인은 서버 함수가 대신 해 준다 (이메일을 앱에 내보내지 않으려고)
      // functions.invoke는 공개 키를 Authorization 헤더에도 넣는데, 새 방식 키(sb_publishable_)는
      // 그 자리에서 거절된다. 그래서 apikey 헤더만 붙여 직접 부른다.
      final data = await _callFunction('login-with-username', {'username': login.toLowerCase(), 'password': password});
      if (data == null) return '아이디 로그인 서버에 연결하지 못했어요. 인터넷을 확인해 주세요';
      if (data['ok'] == true && data['refresh_token'] is String) {
        await _c.auth.setSession(data['refresh_token'] as String);
        return null;
      }
      final err = data['error'];
      if (err == 'email_not_confirmed') return '이메일 인증을 먼저 마쳐 주세요. 가입할 때 받은 메일의 링크를 눌러 주세요';
      if (err == 'too_many') return '로그인 시도가 너무 많아요. 잠시 뒤에 다시 해 주세요';
      return '아이디나 비밀번호가 맞지 않아요';
    } on AuthException catch (e) {
      return _authMessage(e.message);
    } catch (_) {
      return '인터넷 연결을 확인해 주세요';
    }
  }

  /// Edge Function을 apikey 헤더만 붙여 부른다. JSON 답(Map)을 돌려주고, 실패하면 null.
  static Future<Map<String, dynamic>?> _callFunction(String name, Map<String, Object?> body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(Uri.parse('$supabaseUrl/functions/v1/$name'));
      req.headers.set('apikey', supabaseAnonKey);
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final text = await res.transform(utf8.decoder).join();
      final v = jsonDecode(text);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// 회원가입 화면에서 아이디 중복 확인. 확인할 수 없으면 false.
  static Future<bool> usernameTaken(String name) async {
    if (!_ready) return false;
    try {
      return await _c.rpc('username_taken', params: {'name': name.toLowerCase()}) == true;
    } catch (_) {
      return false;
    }
  }

  /// 인증 메일 다시 보내기. 성공하면 null
  static Future<String?> resendConfirmation(String email) async {
    if (!_ready) return '서버 연결 설정이 아직 없어요';
    try {
      await _c.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: emailConfirmedUrl);
      return null;
    } on AuthException catch (e) {
      return _authMessage(e.message);
    } catch (_) {
      return '인터넷 연결을 확인해 주세요';
    }
  }

  /// 카카오·구글 로그인 뒤 앱으로 돌아오는 주소. Supabase 대시보드 Redirect URLs에도 같은 값을 등록한다.
  static const redirectUrl = 'golmok://login-callback';

  /// 이메일 인증 링크를 누르면 열리는 페이지. Supabase Redirect URLs에도 등록한다.
  static const emailConfirmedUrl = 'https://ryu-ji-whan.github.io/golmok_flutter/auth/';

  /// 카카오·구글 로그인 화면(브라우저)을 연다. 로그인이 끝나면 [authChanges]로 signedIn이 온다.
  static Future<String?> signInWithProvider(OAuthProvider provider) async {
    if (!_ready) return '서버 연결 설정이 아직 없어요';
    try {
      // 카카오톡 앱·브라우저에 이미 로그인돼 있으면 바로 넘어가도록 바깥 브라우저로 연다
      final opened = await _c.auth.signInWithOAuth(provider, redirectTo: redirectUrl, authScreenLaunchMode: LaunchMode.externalApplication);
      return opened ? null : '로그인 화면을 열지 못했어요';
    } on AuthException catch (e) {
      return _authMessage(e.message);
    } catch (_) {
      return '인터넷 연결을 확인해 주세요';
    }
  }

  static Stream<AuthState>? get authChanges => _ready ? _c.auth.onAuthStateChange : null;

  /// 소셜 계정에 들어 있는 이름 (닉네임 칸을 미리 채울 때)
  static String? get displayName {
    final m = user?.userMetadata;
    if (m == null) return null;
    for (final k in ['nickname', 'name', 'full_name', 'preferred_username']) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
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
    if (s.contains('invalid login')) return '아이디나 비밀번호가 맞지 않아요';
    if (s.contains('not confirmed')) return '이메일 인증을 먼저 마쳐 주세요. 가입할 때 받은 메일의 링크를 눌러 주세요';
    if (s.contains('rate limit') || s.contains('security purposes')) return '잠시 뒤에 다시 해 주세요 (메일·로그인 횟수 제한)';
    if (s.contains('already registered') || s.contains('already been registered')) return '이미 가입한 이메일이에요. 아이디로 로그인해 주세요';
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
  // 칸 → 그 칸을 밝힐 때 있던 동네 (모르면 null)
  static final Map<String, String?> _pendingCells = {};
  static Timer? _flushTimer;

  static void addExplored(Iterable<String> cells, {String? area}) {
    if (!signedIn) return;
    for (final c in cells) {
      _pendingCells[c] = area ?? _pendingCells[c];
    }
    _flushTimer ??= Timer(const Duration(seconds: 20), flushExplored);
  }

  /// 동네를 모른 채 올린(또는 올릴) 칸에 동네 이름 채우기
  static void tagCells(Iterable<String> cells, String area) => addExplored(cells, area: area);

  static Future<void> flushExplored() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingCells.isEmpty) return;
    final tagged = [for (final e in _pendingCells.entries) if (e.value != null) {'cell': e.key, 'area': e.value}];
    final plain = [for (final e in _pendingCells.entries) if (e.value == null) {'cell': e.key}];
    _pendingCells.clear();
    // 동네를 아는 칸은 동네 이름까지 덮어쓰고, 모르는 칸은 새로 생길 때만 넣는다 (있던 동네 이름을 지우지 않게)
    if (tagged.isNotEmpty) await _try(() => _c.from('explored').upsert(tagged, onConflict: 'user_id,cell'));
    if (plain.isNotEmpty) await _try(() => _c.from('explored').upsert(plain, onConflict: 'user_id,cell', ignoreDuplicates: true));
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

  /// 한 동네의 이번 주 순위 (그 동네에서 실제로 밝힌 칸 수). 실패하면 null
  static Future<List<RemoteRank>?> areaLeaderboard(String area) async {
    if (!signedIn) return null;
    try {
      final rows = await _c.rpc('area_leaderboard', params: {'area_name': area, 'period_days': 7});
      return [
        for (final r in rows as List)
          RemoteRank(r['nickname'] as String, r['character_id'] as String, (r['cells'] as num).toInt(), isMe: r['is_me'] == true),
      ];
    } catch (_) {
      return null;
    }
  }

  /// 내가 이번 주 걸은 동네들과 동네마다 내 순위. 실패하면 null
  static Future<List<MyArea>?> myAreas() async {
    if (!signedIn) return null;
    try {
      final rows = await _c.rpc('my_areas', params: {'period_days': 7});
      return [
        for (final r in rows as List)
          MyArea(r['area'] as String, (r['cells'] as num).toInt(), (r['rank'] as num).toInt(), (r['people'] as num).toInt()),
      ];
    } catch (_) {
      return null;
    }
  }

  /// 리더보드에 내 이름 숨기기
  static Future<bool> setHideRank(bool hide) async {
    if (!signedIn) return false;
    try {
      await _c.from('profiles').update({'hide_rank': hide}).eq('user_id', user!.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool?> hideRank() async {
    if (!signedIn) return null;
    try {
      final r = await _c.from('profiles').select('hide_rank').eq('user_id', user!.id).maybeSingle();
      return r?['hide_rank'] == true;
    } catch (_) {
      return null;
    }
  }
}
