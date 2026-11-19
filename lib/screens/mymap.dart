import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/cartoon_map.dart';
import '../widgets/route_thumb.dart';
import '../widgets/ui.dart';
import 'map_decorate.dart';
import 'map_theme.dart';
import 'spot_detail.dart';
import 'walk.dart';

/// ③-2 내 지도: 지금까지 밝힌 골목 + 지난 산책 경로 + 붙인 스티커
class MyMapTab extends StatefulWidget {
  const MyMapTab({super.key, required this.active});
  final bool active;

  @override
  State<MyMapTab> createState() => _MyMapTabState();
}

class _MyMapTabState extends State<MyMapTab> {
  final _map = MapHandle();
  int _view = 0; // 0 = 장소, 1 = 산책
  LatLng? _pick; // 지도에서 고른, 스티커 붙일 자리

  void _onMapEvent(Map<String, dynamic> msg) {
    if (msg['type'] != 'mapTap') return;
    final p = explorePick(context, msg);
    setState(() => _pick = p);
    _map.setPick(p);
  }

  Future<void> _recordAt(LatLng at) async {
    setState(() => _pick = null);
    await _map.setPick(null);
    if (mounted) await recordAt(context, _map, at: at);
  }

  Future<void> _sync() async {
    final s = StoreScope.read(context);
    await _map.setExplored(s.explored);
    await _map.setOldPaths([for (final w in s.walks) w.path]);
    await _map.setMarks(buildMarks(s));
    await _map.setMe(s.center);
    await _map.setDecos(s.decos);
  }

  Future<void> _ready() async {
    final center = StoreScope.read(context).center;
    await _sync();
    await _map.goTo(center, zoom: 15.5);
  }

  @override
  void didUpdateWidget(MyMapTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _sync(); // 탭을 다시 열 때 새 기록 반영
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 지도'),
        actions: [
          Pill('총 ${formatDistance(s.totalDistance)}'),
          IconButton(
            tooltip: '지도 테마',
            icon: Icon(Icons.palette_outlined, color: C.forest),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapThemeScreen())),
          ),
          TextButton.icon(
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const MapDecorateScreen()));
              if (saved == true) _sync();
            },
            icon: const Icon(Icons.brush_outlined, size: 18),
            label: const Text('꾸미기', style: TextStyle(fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(foregroundColor: C.forest),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(R.big),
            child: Container(
              height: 300,
              decoration: BoxDecoration(border: Border.all(color: C.ink, width: 2), borderRadius: BorderRadius.circular(R.big)),
              child: Stack(children: [
                Positioned.fill(child: CartoonMap(handle: _map, onReady: _ready, onTap: (k, id) => openMark(context, k, id), onEvent: _onMapEvent)),
                if (_pick != null)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: PickCard(
                      onCancel: () {
                        setState(() => _pick = null);
                        _map.setPick(null);
                      },
                      onOk: () => _recordAt(_pick!),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text('기록한 장소 ${s.spots.length}')),
              ButtonSegment(value: 1, label: Text('산책 기록 ${s.walks.length}')),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _view = v.first),
            style: SegmentedButton.styleFrom(selectedBackgroundColor: C.mint, selectedForegroundColor: C.forest),
          ),
        ),
        Expanded(child: _view == 0 ? _spotList(s) : _walkList(s)),
      ]),
    );
  }

  Widget _empty(String text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const StickerImg('a02', size: 90),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: C.muted, height: 1.5)),
        ]),
      );

  Widget _spotList(AppStore s) {
    if (s.spots.isEmpty) return _empty('아직 붙인 스티커가 없어요\n산책하다 마음에 드는 곳에 붙여 보세요');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: s.spots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final sp = s.spots[i];
        return CardBox(
          padding: const EdgeInsets.all(12),
          onTap: () {
            _map.goTo(sp.pos, zoom: 17);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: sp.id)));
          },
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: StickerImg(sp.stickerId, size: 46),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sp.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${formatDate(sp.createdAt)} · ${sp.fromName != null ? '${sp.fromName}님이 보냄' : visibilityLabel[sp.visibility]}${sp.shared ? ' · 피드 공유' : ''}',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
            if (sp.photo != null) Icon(Icons.photo_outlined, color: C.leaf, size: 20),
            Icon(Icons.chevron_right, color: C.muted),
          ]),
        );
      },
    );
  }

  Widget _walkList(AppStore s) {
    if (s.walks.isEmpty) return _empty('아직 끝낸 산책이 없어요\n산책 탭에서 첫 산책을 시작해 보세요');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: s.walks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final w = s.walks[i];
        return CardBox(
          padding: const EdgeInsets.all(14),
          onTap: w.path.isEmpty ? null : () => _map.goTo(w.path.first, zoom: 16),
          child: Row(children: [
            RouteThumb(w.path, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${formatDate(w.startedAt)} 산책', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('${formatDistance(w.distanceM)} · ${formatDuration(w.duration)}',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
