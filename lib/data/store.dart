import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'content.dart';
import 'db.dart';
import 'geo.dart';
import 'models.dart';
import 'places.dart';
import 'remote.dart';
import '../theme.dart';
import '../widgets/photo.dart';

final _rand = math.Random();
String newId(String prefix) =>
    '${prefix}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${_rand.nextInt(1 << 30).toRadixString(36)}';

/// 위치 권한 결과
enum LocateResult { ok, serviceOff, denied, deniedForever }

/// 앱 전체 상태. 바뀌는 내용은 바로 데이터베이스(AppDb)에 저장한다.
class AppStore extends ChangeNotifier {
  AppStore._(this._db);
  final AppDb _db;

  Profile? profile;
  List<Walk> walks = [];
  Walk? activeWalk;
  List<Spot> spots = [];
  Set<String> explored = {};
  Set<String> owned = {};
  Set<String> stamps = {};
  Set<String> rewards = {};
  Set<String> visitedStores = {};
  List<Coupon> coupons = [];

  /// 내 지도에 붙인 꾸미기 (폰에만 저장)
  List<MapDeco> decos = [];
  final Set<String> likedPosts = {};

  /// 처음 위치를 잡은 곳. 캠페인 스팟·제휴 가게를 이 주변에 놓는다(데모).
  LatLng? home;
  LatLng? lastPos;

  /// 지금 있는 동네 (예: "수원시 팔달구 행궁동"). 300m 넘게 움직이면 다시 확인한다.
  String? currentArea;
  LatLng? _areaAt;
  bool _areaBusy = false;
  DateTime? _areaFailedAt; // 실패하면 30초 쉬었다가 다시 (지도 서버 이용 규칙)
  // 동네를 아직 모를 때 밝힌 칸 (동네를 알게 되면 이름을 채운다)
  final Set<String> _untagged = {};
  // 동네를 아직 모를 때 걸은 거리 (동네를 알게 되면 그 동네에 더한다)
  double _untaggedMeters = 0;

  /// 리더보드에 내 이름 숨기기
  bool hideRank = false;

  /// 지도 테마 (assets/map/cartoon_map.html 의 THEMES). 폰에만 저장
  String mapTheme = 'pastel';

  /// 친구에게 받았지만 아직 받기·거절하지 않은 스티커
  List<Gift> gifts = [];

  /// 나에게 온 친구 요청 수
  int friendRequests = 0;
  DateTime? _inboxAt;

  /// 새로 밝힌 칸 (지도에 바로 보내기 위해)
  final List<String> _freshCells = [];

  StreamSubscription<Position>? _gps;
  Timer? _demoTimer;
  double _demoHeading = 0;
  bool get demoWalking => _demoTimer != null;

  bool get loggedIn => profile?.loggedIn ?? false;

  static Future<AppStore> load() async {
    final db = await AppDb.open();
    final s = AppStore._(db);
    s.profile = await db.profile();
    s.walks = await db.walks();
    // 앱이 꺼졌을 때 끝나지 않은 산책은 이어서 보여 준다.
    final open = s.walks.where((w) => w.endedAt == null).toList();
    if (open.isNotEmpty) {
      s.activeWalk = open.first;
      s.walks.remove(open.first);
    }
    s.spots = await db.spots();
    s.explored = await db.explored();
    // 안개 칸 크기가 50m → 20m로 바뀌었다. 예전 기록이면 한 번만 옮긴다.
    if (await db.kv('cell_m') != '20') {
      if (s.explored.isNotEmpty) {
        s.explored = migrateCells50to20(s.explored);
        await db.replaceExplored(s.explored);
        if (Remote.signedIn) {
          await Remote.replaceExplored(s.explored);
          await Remote.addMarks('meta', ['cell20']);
        }
      }
      await db.setKv('cell_m', '20');
    }
    s.owned = await db.marks('owned');
    if (s.owned.isEmpty) {
      s.owned = starterStickers.toSet();
      await db.addMarks('owned', s.owned);
    }
    s.stamps = await db.marks('stamp');
    s.rewards = await db.marks('reward');
    s.visitedStores = await db.marks('store');
    s.coupons = await db.coupons();
    final h = await db.kv('home');
    if (h != null) {
      final parts = h.split(',');
      s.home = LatLng(double.parse(parts[0]), double.parse(parts[1]));
    }
    s.lastPos = s.home;
    s.hideRank = await db.kv('hide_rank') == '1';
    s.mapTheme = await db.kv('map_theme') ?? 'pastel';
    C.use(s.mapTheme);
    try {
      final raw = await db.kv('map_deco');
      if (raw != null) s.decos = [for (final j in jsonDecode(raw) as List) MapDeco.fromJson(j as Map<String, dynamic>)];
    } catch (_) {}
    return s;
  }

  LatLng get center => lastPos ?? home ?? defaultCenter;

  List<String> takeFreshCells() {
    final out = List<String>.from(_freshCells);
    _freshCells.clear();
    return out;
  }

  // ── 계정 ──
  /// 서버에 닉네임이 겹치면 오류 문장을 돌려주고 가입하지 않는다.
  Future<String?> signup(Profile p, List<String> gift) async {
    if (Remote.signedIn) {
      final err = await Remote.saveProfile(p);
      if (err != null) return err;
    }
    profile = p;
    await _db.saveProfile(p);
    await own(gift);
    if (Remote.signedIn) {
      // 로그인 전에 이 폰에서 걸었던 기록도 내 계정으로 올린다.
      await Remote.uploadAll(
        walks: walks,
        spots: spots,
        explored: explored,
        marks: {'owned': owned, 'stamp': stamps, 'reward': rewards, 'store': visitedStores, 'meta': {'cell20'}},
        coupons: coupons,
      );
    }
    return null;
  }

  /// 이메일로 로그인한 뒤: 서버에 내 데이터가 있으면 이 폰을 그 데이터로 바꾼다.
  /// 서버에 프로필이 있으면 true(바로 산책 화면), 없으면 false(회원가입 이어서).
  Future<bool> afterRemoteLogin() async {
    final d = await Remote.fetchAll();
    if (d == null || d.profile == null) return false;
    stopTracking();
    // 지도 꾸미기는 아직 서버에 없다. 같은 계정으로 다시 로그인한 거면 이 폰의 꾸미기를 남긴다.
    final keepDecos = profile?.nickname == d.profile!.nickname;
    await _db.wipe();
    if (keepDecos && decos.isNotEmpty) {
      await _db.setKv('map_deco', jsonEncode([for (final x in decos) x.toJson()]));
    } else {
      decos = [];
    }
    profile = d.profile;
    await _db.saveProfile(d.profile!);
    for (final w in d.walks) {
      await _db.saveWalk(w);
      await _db.addPoints(w.id, w.path);
    }
    for (final s in d.spots) {
      await _db.saveSpot(s);
    }
    var cells = d.explored;
    if (cells.isNotEmpty && !(d.marks['meta']?.contains('cell20') ?? false)) {
      // 서버에 예전(50m 칸) 기록이 있으면 20m 칸으로 옮겨서 다시 올린다
      cells = migrateCells50to20(cells);
      await Remote.replaceExplored(cells);
    }
    await Remote.addMarks('meta', ['cell20']);
    await _db.addExplored(cells);
    await _db.setKv('cell_m', '20');
    owned = {...starterStickers, ...?d.marks['owned']};
    stamps = d.marks['stamp'] ?? {};
    rewards = d.marks['reward'] ?? {};
    visitedStores = d.marks['store'] ?? {};
    await _db.addMarks('owned', owned);
    await _db.addMarks('stamp', stamps);
    await _db.addMarks('reward', rewards);
    await _db.addMarks('store', visitedStores);
    for (final c in d.coupons) {
      await _db.saveCoupon(c);
    }
    walks = d.walks.where((w) => w.endedAt != null).toList();
    activeWalk = null;
    spots = d.spots;
    explored = cells;
    coupons = d.coupons;
    if (home != null) await _db.setKv('home', '${home!.lat},${home!.lng}');
    hideRank = await Remote.hideRank() ?? hideRank;
    await _db.setKv('hide_rank', hideRank ? '1' : '0');
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    if (activeWalk != null) await endWalk();
    if (profile != null) {
      profile = profile!.copyWith(loggedIn: false);
      await _db.saveProfile(profile!);
    }
    await Remote.signOut();
    notifyListeners();
  }

  /// 로그아웃했던 계정과 같은 방법으로 들어오면 가입 없이 돌아간다.
  bool canRestore(String provider) => profile != null && !profile!.loggedIn && profile!.provider == provider;

  Future<void> restoreLogin() async {
    profile = profile!.copyWith(loggedIn: true);
    await _db.saveProfile(profile!);
    notifyListeners();
  }

  /// 서버에 닉네임이 겹치면 오류 문장을 돌려준다.
  Future<String?> updateProfile({String? nickname, String? characterId, String? areaName}) async {
    final next = profile!.copyWith(nickname: nickname, characterId: characterId, areaName: areaName);
    final err = await Remote.saveProfile(next);
    if (err != null) return err;
    profile = next;
    await _db.saveProfile(profile!);
    notifyListeners();
    return null;
  }

  Future<void> reset() async {
    stopTracking();
    await Remote.signOut();
    await _db.wipe();
    await _db.setKv('cell_m', '20');
    profile = null;
    walks = [];
    activeWalk = null;
    spots = [];
    explored = {};
    owned = starterStickers.toSet();
    await _db.addMarks('owned', owned);
    stamps = {};
    rewards = {};
    visitedStores = {};
    coupons = [];
    decos = [];
    gifts = [];
    friendRequests = 0;
    likedPosts.clear();
    home = null;
    lastPos = null;
    notifyListeners();
  }

  // ── 위치 ──
  Future<LocateResult> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocateResult.serviceOff;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) return LocateResult.deniedForever;
    if (perm == LocationPermission.denied) return LocateResult.denied;
    return LocateResult.ok;
  }

  /// 현재 위치를 한 번 잡는다.
  Future<LocateResult> locate() async {
    final r = await ensurePermission();
    if (r != LocateResult.ok) return r;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      await onPosition(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // 실내 등에서 시간 초과면 마지막 위치를 그대로 쓴다.
    }
    return LocateResult.ok;
  }

  Future<LocateResult> startTracking() async {
    final r = await ensurePermission();
    if (r != LocateResult.ok) return r;
    await _gps?.cancel();
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((pos) {
      if (_demoTimer == null) onPosition(LatLng(pos.latitude, pos.longitude));
    });
    return LocateResult.ok;
  }

  void stopTracking() {
    _gps?.cancel();
    _gps = null;
    stopDemoWalk();
  }

  /// 책상에서도 시험할 수 있게 1초마다 8m씩 골목을 걷는 흉내를 낸다.
  void startDemoWalk() {
    _demoTimer?.cancel();
    _demoHeading = _rand.nextDouble() * 2 * math.pi;
    _demoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _demoHeading += (_rand.nextDouble() - 0.5) * 0.9;
      final p = center;
      onPosition(offset(p, math.cos(_demoHeading) * 8, math.sin(_demoHeading) * 8));
    });
    notifyListeners();
  }

  void stopDemoWalk() {
    _demoTimer?.cancel();
    _demoTimer = null;
    notifyListeners();
  }

  Future<void> onPosition(LatLng p) async {
    final prev = lastPos;
    lastPos = p;
    if (home == null) {
      home = p;
      await _db.setKv('home', '${p.lat},${p.lng}');
    }
    final fresh = cellsAround(p).where((c) => !explored.contains(c)).toList();
    final areaHere = _areaFresh(p) ? currentArea : null;
    if (fresh.isNotEmpty) {
      explored.addAll(fresh);
      _freshCells.addAll(fresh);
      if (areaHere == null) _untagged.addAll(fresh);
      await _db.addExplored(fresh, area: areaHere);
      Remote.addExplored(fresh, area: areaHere);
    }
    _lookupArea(p);
    final w = activeWalk;
    if (w != null) {
      final step = prev == null ? 0.0 : distanceM(prev, p);
      // GPS가 크게 튀는 값(200m 넘게 순간이동)은 거리에 넣지 않는다.
      if (step < 200) {
        w.distanceM += step;
        // 동네 리더보드: 지금 있는 동네에 걸은 거리를 더한다
        if (areaHere != null) {
          Remote.addAreaMeters(areaHere, step);
        } else {
          _untaggedMeters += step;
        }
      }
      w.newCells += fresh.length;
      w.path.add(p);
      await _db.addPoint(w.id, w.path.length, p);
      await _db.saveWalk(w);
    }
    notifyListeners();
  }

  // ── 지금 있는 동네 ──
  bool _areaFresh(LatLng p) => currentArea != null && _areaAt != null && distanceM(_areaAt!, p) < 300;

  /// 지금 위치의 동네 이름을 (필요할 때만) 지도 서버에 물어본다
  Future<void> _lookupArea(LatLng p, {bool force = false}) async {
    if (_areaBusy || (!force && _areaFresh(p))) return;
    final failed = _areaFailedAt;
    if (!force && failed != null && DateTime.now().difference(failed) < const Duration(seconds: 30)) return;
    _areaBusy = true;
    try {
      final place = await Places.reverse(p.lat, p.lng);
      if (place == null) {
        _areaFailedAt = DateTime.now();
        return;
      }
      _areaFailedAt = null;
      currentArea = place.name;
      _areaAt = p;
      if (_untaggedMeters > 0) {
        Remote.addAreaMeters(place.name, _untaggedMeters);
        _untaggedMeters = 0;
      }
      if (_untagged.isNotEmpty) {
        final cells = _untagged.toList();
        _untagged.clear();
        await _db.tagCells(cells, place.name);
        Remote.tagCells(cells, place.name);
      }
      notifyListeners();
    } finally {
      _areaBusy = false;
    }
  }

  /// 리더보드를 열 때: 위치를 새로 잡고 지금 동네를 확인한다. 모르면 null
  Future<String?> refreshCurrentArea() async {
    await locate();
    final p = lastPos;
    if (p != null) await _lookupArea(p, force: currentArea == null);
    return currentArea;
  }

  Future<void> setHideRank(bool hide) async {
    hideRank = hide;
    await _db.setKv('hide_rank', hide ? '1' : '0');
    notifyListeners();
    await Remote.setHideRank(hide);
  }

  // ── 산책 ──
  Future<LocateResult> startWalk() async {
    final r = await startTracking();
    final w = Walk(id: newId('walk'), startedAt: DateTime.now());
    activeWalk = w;
    await _db.saveWalk(w);
    if (lastPos != null) {
      w.path.add(lastPos!);
      await _db.addPoint(w.id, 1, lastPos!);
    }
    notifyListeners();
    return r;
  }

  Future<Walk?> endWalk() async {
    final w = activeWalk;
    if (w == null) return null;
    stopTracking();
    w.endedAt = DateTime.now();
    await _db.saveWalk(w);
    walks.insert(0, w);
    activeWalk = null;
    notifyListeners();
    Remote.saveWalk(w);
    Remote.flushExplored();
    return w;
  }

  int get weeklyCells {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final done = walks.where((w) => w.startedAt.isAfter(weekAgo)).fold<int>(0, (n, w) => n + w.newCells);
    return done + (activeWalk?.newCells ?? 0);
  }

  /// 최근 7일 동안 걸은 거리
  double get weeklyDistance {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return walks.where((w) => w.startedAt.isAfter(weekAgo)).fold<double>(0, (n, w) => n + w.distanceM) + (activeWalk?.distanceM ?? 0);
  }

  /// 산책한 날 수
  int get walkDays => {for (final w in walks) '${w.startedAt.year}-${w.startedAt.month}-${w.startedAt.day}'}.length;

  double get totalDistance => walks.fold<double>(0, (n, w) => n + w.distanceM) + (activeWalk?.distanceM ?? 0);

  // ── 기록 (스티커 붙인 장소) ──
  /// [at]이 있으면 그 자리(내가 밝힌 곳)에, 없으면 지금 있는 자리에 붙인다
  Future<Spot> addSpot({required String stickerId, required String title, required String memo, required SpotVisibility visibility, String? photo, LatLng? at}) async {
    final p = at ?? center;
    final s = Spot(
      id: newId('spot'),
      lat: p.lat,
      lng: p.lng,
      stickerId: stickerId,
      title: title,
      memo: memo,
      visibility: visibility,
      photo: photo,
      walkId: at == null ? activeWalk?.id : null,
      createdAt: DateTime.now(),
    );
    spots.insert(0, s);
    await _db.saveSpot(s);
    notifyListeners();
    Remote.saveSpot(s);
    return s;
  }

  Future<void> updateSpot(Spot s) async {
    spots = [for (final x in spots) x.id == s.id ? s : x];
    await _db.saveSpot(s);
    notifyListeners();
    Remote.saveSpot(s);
  }

  Future<void> deleteSpot(String id) async {
    spots.removeWhere((x) => x.id == id);
    await _db.deleteSpot(id);
    notifyListeners();
    Remote.deleteSpot(id);
  }

  /// 지도 꾸미기 저장
  Future<void> saveDecos(List<MapDeco> list) async {
    decos = list;
    await _db.setKv('map_deco', jsonEncode([for (final d in list) d.toJson()]));
    notifyListeners();
  }

  /// 지도 테마 = 앱 테마. 색·제목 글씨체를 바꾸고 화면 전체를 새 색으로 다시 그린다
  Future<void> setMapTheme(String id) async {
    mapTheme = id;
    C.use(id);
    await _db.setKv('map_theme', id);
    notifyListeners();
    // 화면들이 색을 C에서 직접 읽으므로 모든 화면을 한 번 다시 그린다 (지금 보던 화면·상태는 그대로)
    WidgetsBinding.instance.reassembleApplication();
  }

  // ── 친구에게 받은 스티커 ──
  /// 받은 스티커·친구 요청을 서버에서 확인한다. [force]가 아니면 30초 안에 다시 묻지 않는다.
  Future<void> refreshInbox({bool force = false}) async {
    if (!Remote.signedIn) return;
    final at = _inboxAt;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(seconds: 30)) return;
    _inboxAt = DateTime.now();
    final g = await Remote.gifts();
    final f = await Remote.friends();
    gifts = g;
    if (f != null) friendRequests = f.where((x) => x.state == 'received').length;
    notifyListeners();
  }

  void setFriendRequests(int n) {
    if (n == friendRequests) return;
    friendRequests = n;
    notifyListeners();
  }

  /// 받기: 사진을 내려받아 내 기록으로 만든다. 받은 순간부터 내 것 (보낸 사람이 지워도 남음)
  Future<Spot> acceptGift(Gift g) async {
    String? photo;
    if (g.photo != null) {
      final bytes = await Remote.giftPhoto(g.photo!);
      if (bytes != null) photo = await Photos.saveBytes(bytes, ext: g.photo!.toLowerCase().endsWith('.png') ? '.png' : '.jpg');
    }
    final sp = Spot(
      id: newId('spot'),
      lat: g.lat,
      lng: g.lng,
      stickerId: g.stickerId,
      title: g.title,
      memo: g.memo,
      photo: photo,
      visibility: SpotVisibility.me,
      createdAt: DateTime.now(),
      fromName: g.fromName,
    );
    spots.insert(0, sp);
    await _db.saveSpot(sp);
    gifts.removeWhere((x) => x.id == g.id);
    notifyListeners();
    Remote.saveSpot(sp);
    await Remote.closeGift(g);
    return sp;
  }

  Future<void> declineGift(Gift g) async {
    gifts.removeWhere((x) => x.id == g.id);
    notifyListeners();
    await Remote.closeGift(g);
  }

  Spot? spotById(String id) {
    for (final s in spots) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ── 스티커·보상 ──
  Future<void> own(Iterable<String> ids) async {
    owned.addAll(ids);
    await _db.addMarks('owned', ids);
    notifyListeners();
    Remote.addMarks('owned', ids);
  }

  Future<void> claimReward(String rewardId, List<String> stickerIds, {Coupon? coupon}) async {
    rewards.add(rewardId);
    await _db.addMarks('reward', [rewardId]);
    Remote.addMarks('reward', [rewardId]);
    if (coupon != null) {
      coupons.insert(0, coupon);
      await _db.saveCoupon(coupon);
      Remote.saveCoupon(coupon);
    }
    await own(stickerIds);
  }

  void toggleLike(String postId) {
    if (!likedPosts.remove(postId)) likedPosts.add(postId);
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

/// 화면 어디서나 AppStore를 꺼내 쓰기 위한 통로. 값이 바뀌면 다시 그린다.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// 다시 그리지 않고 꺼내기 (버튼 눌렀을 때 등)
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
