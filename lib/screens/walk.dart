import 'dart:async';

import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/cartoon_map.dart';
import '../widgets/route_thumb.dart';
import '../widgets/ui.dart';
import 'gift_receive.dart';
import 'profile.dart';
import 'record.dart';
import 'spot_detail.dart';

/// 지도 위 스티커(내 기록)를 눌렀을 때
void openMark(BuildContext context, String kind, String id) {
  if (kind == 'spot') {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: id)));
  }
}

/// 지도 표시: 내가 붙인 스티커 기록
List<MapMark> buildMarks(AppStore s) => [
      for (final sp in s.spots) MapMark(id: sp.id, pos: sp.pos, sticker: sp.stickerId, kind: 'spot', label: sp.title),
    ];

/// 지도 빈 곳을 눌렀을 때 스티커 붙일 자리. 내가 걸어서 밝힌 곳만 되고, 안개 낀 곳이면 알려 주고 null
LatLng? explorePick(BuildContext context, Map<String, dynamic> msg) {
  if (msg['type'] != 'mapTap' || msg['lat'] == null) return null;
  final p = LatLng((msg['lat'] as num).toDouble(), (msg['lng'] as num).toDouble());
  if (StoreScope.read(context).explored.contains(cellOf(p))) return p;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('아직 안개 낀 곳이에요. 걸어서 밝힌 곳에만 스티커를 붙일 수 있어요'), duration: Duration(seconds: 2)));
  return null;
}

/// 기록 화면을 열고, 저장하고 돌아오면 지도에 스티커를 콩 찍는다. [at]이 없으면 지금 있는 자리. 저장했으면 true
Future<bool> recordAt(BuildContext context, MapHandle map, {LatLng? at}) async {
  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RecordScreen(at: at)));
  if (saved != true || !context.mounted) return false;
  final s = StoreScope.read(context);
  if (s.spots.isEmpty) return true;
  await map.setMarks(buildMarks(s));
  await Future<void>.delayed(const Duration(milliseconds: 250));
  await map.stamp(s.spots.first.id);
  return true;
}

/// 고른 자리에 붙일지 묻는 카드
class PickCard extends StatelessWidget {
  const PickCard({super.key, required this.onCancel, required this.onOk});
  final VoidCallback onCancel, onOk;

  @override
  Widget build(BuildContext context) => CardBox(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(children: [
          Icon(Icons.add_location_alt, color: C.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('이 자리에 스티커를 붙일까요?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('내가 걸어서 밝힌 골목이에요', style: TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
          TextButton(onPressed: onCancel, child: Text('취소', style: TextStyle(color: C.muted))),
          FilledButton(
            onPressed: onOk,
            style: FilledButton.styleFrom(backgroundColor: C.orange, shape: const StadiumBorder()),
            child: const Text('붙이기'),
          ),
        ]),
      );
}

/// ①-4 산책 시작 / ②-1 산책 중 지도
class WalkTab extends StatefulWidget {
  const WalkTab({super.key});

  @override
  State<WalkTab> createState() => _WalkTabState();
}

class _WalkTabState extends State<WalkTab> {
  final _map = MapHandle();
  AppStore? _store;
  Timer? _tick;
  int _spotCount = -1;
  bool _wasWalking = false;
  LatLng? _pick; // 지도에서 고른, 스티커 붙일 자리

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = StoreScope.read(context);
    if (_store != s) {
      _store?.removeListener(_onStore);
      _store = s..addListener(_onStore);
    }
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _store?.activeWalk != null) setState(() {});
    });
    // 첫 화면에서 현재 위치를 한 번 잡아 둔다 (권한은 가입 때 물어봄)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = StoreScope.read(context);
      // 앱을 켜면 늘 지금 위치를 새로 잡고 그리로 간다 (예전엔 처음 쓴 자리(home)에 머물러 있었음)
      await s.locate();
      if (mounted && s.lastPos != null) await _map.goTo(s.center, zoom: 16.5);
      if (s.activeWalk != null) await s.startTracking(); // 앱을 다시 켰을 때 이어서 기록
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _store?.removeListener(_onStore);
    super.dispose();
  }

  Future<void> _fullSync() async {
    final s = _store!;
    s.takeFreshCells();
    await _map.setExplored(s.explored);
    await _map.setMe(s.center);
    await _map.setPath(s.activeWalk?.path ?? const []);
    await _map.setMarks(buildMarks(s));
    _spotCount = s.spots.length;
    await _map.goTo(s.center, zoom: 16.5);
  }

  void _onStore() {
    final s = _store!;
    if (!_map.ready) return;
    _map.addExplored(s.takeFreshCells());
    _map.setMe(s.center);
    final walking = s.activeWalk != null;
    if (walking) {
      _map.setPath(s.activeWalk!.path);
      _map.goTo(s.center);
    } else if (_wasWalking) {
      _map.setPath(const []);
    }
    _wasWalking = walking;
    if (s.spots.length != _spotCount) {
      _spotCount = s.spots.length;
      _map.setMarks(buildMarks(s));
    }
  }

  Future<void> _start() async {
    final s = StoreScope.read(context);
    final r = await s.startWalk();
    if (!mounted) return;
    if (r != LocateResult.ok) {
      toast(context, '위치 권한이 없어서 "데모 걷기"로 시험해 볼 수 있어요');
    }
  }

  Future<void> _end() async {
    final s = StoreScope.read(context);
    final ok = await confirm(context, '산책을 끝낼까요?', '지금까지 걸은 길과 밝힌 골목이 기록에 저장돼요.', ok: '끝내기');
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    final w = await s.endWalk();
    if (w != null) nav.push(MaterialPageRoute(builder: (_) => WalkSummaryScreen(walk: w)));
  }

  /// 기록하고 돌아오면 방금 붙인 스티커를 도장처럼 콩 찍는다. [at]이 있으면 지도에서 고른 자리
  Future<void> _record({LatLng? at}) async {
    setState(() => _pick = null);
    await _map.setPick(null);
    if (!mounted) return;
    _spotCount = -1; // 돌아오면 스티커 표시를 다시 그리게
    await recordAt(context, _map, at: at);
    _spotCount = StoreScope.read(context).spots.length;
  }

  /// 지도 빈 곳을 누르면: 밝힌 곳이면 그 자리에 붙일지 묻는다
  void _onMapEvent(Map<String, dynamic> msg) {
    if (msg['type'] != 'mapTap') return;
    final p = explorePick(context, msg);
    setState(() => _pick = p);
    _map.setPick(p);
  }

  Future<void> _locate() async {
    final s = StoreScope.read(context);
    final r = await s.locate();
    if (!mounted) return;
    if (r != LocateResult.ok) toast(context, '위치를 켜면 내 자리로 이동해요');
    await _map.goTo(s.center, zoom: 16.5);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final w = s.activeWalk;
    final p = s.profile;
    return Stack(children: [
      Positioned.fill(
        child: CartoonMap(handle: _map, onReady: _fullSync, onTap: (k, id) => openMark(context, k, id), onEvent: _onMapEvent),
      ),
      // 위: 프로필 + 통계
      Positioned(
        left: 16,
        right: 16,
        top: MediaQuery.of(context).padding.top + 10,
        child: Column(children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999), boxShadow: cardShadow),
                child: Row(children: [
                  Avatar(p?.characterId ?? 'a00', size: 36),
                  const SizedBox(width: 8),
                  Text(p?.nickname ?? '손님', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999), boxShadow: cardShadow),
              child: Text((p?.areaName ?? '').split(' ').last, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.forest)),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: w != null ? C.forest : C.white,
              borderRadius: BorderRadius.circular(R.big),
              boxShadow: cardShadow,
            ),
            child: w != null
                ? Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    Stat(formatDuration(w.duration), '걸은 시간', light: true),
                    Stat(formatDistance(w.distanceM), '거리', light: true),
                    Stat('${s.spots.where((x) => x.walkId == w.id).length}곳', '이번 산책 기록', light: true),
                  ])
                : Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    Stat(formatDistance(s.weeklyDistance), '이번 주 걸은 거리'),
                    Stat(formatDistance(s.totalDistance), '총 걸은 거리'),
                    Stat('${s.spots.length}곳', '기록한 장소'),
                  ]),
          ),
          // 친구가 보낸 스티커가 있으면
          if (s.gifts.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GiftReceiveScreen())),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                decoration: BoxDecoration(color: C.orange, borderRadius: BorderRadius.circular(999), boxShadow: cardShadow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  StickerImg(s.gifts.first.stickerId, size: 30),
                  const SizedBox(width: 8),
                  Text(s.gifts.length == 1 ? '${s.gifts.first.fromName}님이 스티커를 보냈어요' : '친구가 보낸 스티커 ${s.gifts.length}개',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.white)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: C.white, size: 20),
                ]),
              ),
            ),
          ],
        ]),
      ),
      // 오른쪽: 내 위치
      Positioned(
        right: 16,
        bottom: w != null ? 150 : 100,
        child: FloatingActionButton.small(
          heroTag: 'locate',
          backgroundColor: C.white,
          foregroundColor: C.forest,
          onPressed: _locate,
          tooltip: '내 위치',
          child: const Icon(Icons.my_location),
        ),
      ),
      // 아래: 버튼 (지도에서 자리를 골랐으면 붙일지 묻는 카드)
      Positioned(
        left: 16,
        right: 16,
        bottom: 16,
        child: _pick != null
            ? PickCard(
                onCancel: () {
                  setState(() => _pick = null);
                  _map.setPick(null);
                },
                onOk: () => _record(at: _pick),
              )
            : w == null
            ? PrimaryButton('산책 시작', icon: Icons.directions_walk, onPressed: _start)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: Text(s.demoWalking ? '데모 걷기 중' : '데모 걷기'),
                    avatar: const Icon(Icons.smart_toy_outlined, size: 18),
                    selected: s.demoWalking,
                    selectedColor: C.peach,
                    backgroundColor: C.white,
                    onSelected: (on) => on ? s.startDemoWalk() : s.stopDemoWalk(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlineButton('여기 기록하기', icon: Icons.add_location_alt_outlined, onPressed: () => _record()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: PrimaryButton('산책 끝내기', onPressed: _end, color: C.orangeText)),
                ]),
              ]),
      ),
    ]);
  }
}

/// 산책 요약 (산책 끝난 뒤)
class WalkSummaryScreen extends StatelessWidget {
  const WalkSummaryScreen({super.key, required this.walk});
  final Walk walk;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final mine = s.spots.where((x) => x.walkId == walk.id).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 산책')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(children: [
            // 오늘 걸은 경로 + 응원 고양이
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(clipBehavior: Clip.none, children: [
                RouteThumb(walk.path, size: 200, radius: 28),
                const Positioned(right: -6, bottom: -6, child: StickerImg('a04', size: 84)),
              ]),
            ),
            const SizedBox(height: 8),
            Text(walk.distanceM >= 10 ? '${formatDistance(walk.distanceM)} 걸었어요!' : '수고했어요! 다음엔 조금 더 걸어 볼까요?',
                textAlign: TextAlign.center, style: jua(26)),
            const SizedBox(height: 20),
            CardBox(
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Stat(formatDistance(walk.distanceM), '거리'),
                Stat(formatDuration(walk.duration), '시간'),
                Stat('${mine.length}곳', '기록'),
              ]),
            ),
            if (mine.isNotEmpty) ...[
              const SectionTitle('이번 산책에서 붙인 스티커'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final sp in mine)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      StickerImg(sp.stickerId, size: 52),
                      SizedBox(width: 72, child: Text(sp.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                    ]),
                  ),
              ]),
            ],
            const Spacer(),
            PrimaryButton('확인', onPressed: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}
