import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'content.dart';
import 'db.dart';
import 'geo.dart';
import 'models.dart';
import 'remote.dart';

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
  final Set<String> likedPosts = {};

  /// 처음 위치를 잡은 곳. 캠페인 스팟·제휴 가게를 이 주변에 놓는다(데모).
  LatLng? home;
  LatLng? lastPos;

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
        marks: {'owned': owned, 'stamp': stamps, 'reward': rewards, 'store': visitedStores},
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
    await _db.wipe();
    profile = d.profile;
    await _db.saveProfile(d.profile!);
    for (final w in d.walks) {
      await _db.saveWalk(w);
      await _db.addPoints(w.id, w.path);
    }
    for (final s in d.spots) {
      await _db.saveSpot(s);
    }
    await _db.addExplored(d.explored);
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
    explored = d.explored;
    coupons = d.coupons;
    if (home != null) await _db.setKv('home', '${home!.lat},${home!.lng}');
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
    if (fresh.isNotEmpty) {
      explored.addAll(fresh);
      _freshCells.addAll(fresh);
      await _db.addExplored(fresh);
      Remote.addExplored(fresh);
    }
    final w = activeWalk;
    if (w != null) {
      final step = prev == null ? 0.0 : distanceM(prev, p);
      // GPS가 크게 튀는 값(200m 넘게 순간이동)은 거리에 넣지 않는다.
      if (step < 200) w.distanceM += step;
      w.newCells += fresh.length;
      w.path.add(p);
      await _db.addPoint(w.id, w.path.length, p);
      await _db.saveWalk(w);
    }
    notifyListeners();
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

  double get totalDistance => walks.fold<double>(0, (n, w) => n + w.distanceM) + (activeWalk?.distanceM ?? 0);

  // ── 기록 (스티커 붙인 장소) ──
  Future<Spot> addSpot({required String stickerId, required String title, required String memo, required SpotVisibility visibility, String? photo}) async {
    final p = center;
    final s = Spot(
      id: newId('spot'),
      lat: p.lat,
      lng: p.lng,
      stickerId: stickerId,
      title: title,
      memo: memo,
      visibility: visibility,
      photo: photo,
      walkId: activeWalk?.id,
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

  Spot? spotById(String id) {
    for (final s in spots) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ── 스티커·스탬프·쿠폰 ──
  Future<void> own(Iterable<String> ids) async {
    owned.addAll(ids);
    await _db.addMarks('owned', ids);
    notifyListeners();
    Remote.addMarks('owned', ids);
  }

  LatLng campaignPos(CampaignSpot s) => offset(home ?? defaultCenter, s.north, s.east);
  LatLng storePos(Store s) => offset(home ?? defaultCenter, s.north, s.east);

  double? distanceTo(LatLng p) => lastPos == null ? null : distanceM(lastPos!, p);

  Future<void> stamp(String spotId) async {
    stamps.add(spotId);
    await _db.addMarks('stamp', [spotId]);
    notifyListeners();
    Remote.addMarks('stamp', [spotId]);
  }

  bool get campaignDone => Campaign.spots.every((s) => stamps.contains(s.id));

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

  Future<Coupon> visitStore(Store store) async {
    visitedStores.add(store.id);
    await _db.addMarks('store', [store.id]);
    Remote.addMarks('store', [store.id]);
    final c = Coupon(id: newId('cp'), storeId: store.id, title: store.benefit, issuedAt: DateTime.now());
    coupons.insert(0, c);
    await _db.saveCoupon(c);
    Remote.saveCoupon(c);
    await own([store.sticker]);
    return c;
  }

  Future<void> useCoupon(String id) async {
    for (final c in coupons) {
      if (c.id == id) {
        c.usedAt = DateTime.now();
        await _db.saveCoupon(c);
        Remote.saveCoupon(c);
      }
    }
    notifyListeners();
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
