import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../data/models.dart';
import '../data/places.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/image_out.dart';
import '../widgets/photo.dart';
import '../widgets/ui.dart';

/// 친구에게 보내기: 기록 하나(사진·스티커·제목·메모)를 스티커 카드 그림 한 장으로 만들어 공유한다.
/// 카드에는 좌표·경로를 넣지 않는다 (동네 이름은 켜고 끌 수 있음).
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.spot});
  final Spot spot;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  /// 카드 크기 (논리 크기). 4:5 = 인스타그램 세로 사진 비율. 저장할 때 1080×1350으로 그린다.
  static const cardW = 320.0, cardH = 400.0;

  final _key = GlobalKey();
  bool _showArea = true;
  bool _showMemo = true;
  bool _busy = false;
  String? _area; // 기록한 곳의 동 이름 (예: 행궁동)

  @override
  void initState() {
    super.initState();
    _findArea();
  }

  /// 기록한 자리의 동네 이름. 지금 있는 곳 근처면 이미 아는 이름을 쓰고, 아니면 한 번만 물어본다.
  Future<void> _findArea() async {
    final s = StoreScope.read(context);
    final sp = widget.spot;
    String? name;
    if (s.currentArea != null && distanceM(s.center, sp.pos) < 300) {
      name = s.currentArea;
    } else {
      try {
        name = (await Places.reverse(sp.lat, sp.lng))?.name;
      } catch (_) {}
    }
    if (mounted && name != null) setState(() => _area = name!.split(' ').last);
  }

  Future<String?> _render() async {
    final bytes = await ImageOut.capture(_key, pixelRatio: 1080 / cardW);
    return bytes == null ? null : ImageOut.toTemp(bytes, prefix: 'golmok_card');
  }

  Future<void> _run(Future<String?> Function(String path) job, {String? ok}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _render();
      final err = path == null ? '카드를 만들지 못했어요. 다시 해 주세요' : await job(path);
      if (!mounted) return;
      if (err != null) {
        toast(context, err);
      } else if (ok != null) {
        toast(context, ok);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = widget.spot;
    return Scaffold(
      appBar: AppBar(title: const Text('친구에게 보내기')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        const Text('이 카드 한 장이 사진으로 보내져요', style: TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 10),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: AspectRatio(
              aspectRatio: cardW / cardH,
              child: FittedBox(
                child: RepaintBoundary(
                  key: _key,
                  child: SpotCard(spot: sp, area: _showArea ? _area : null, showMemo: _showMemo),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _showArea,
          onChanged: (v) => setState(() => _showArea = v),
          activeTrackColor: C.leaf,
          title: const Text('동네 이름 넣기'),
          subtitle: Text(_area == null ? '동네 이름을 찾는 중이거나 찾지 못했어요' : '$_area · 정확한 위치는 들어가지 않아요'),
        ),
        if (sp.memo.isNotEmpty)
          SwitchListTile(
            value: _showMemo,
            onChanged: (v) => setState(() => _showMemo = v),
            activeTrackColor: C.leaf,
            title: const Text('메모 넣기'),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          _busy ? '카드 만드는 중…' : '친구에게 보내기',
          icon: Icons.send_outlined,
          onPressed: _busy ? null : () => _run((path) => ImageOut.share(path, text: '골목대장에서 남긴 골목 기록이에요 #골목대장')),
        ),
        const SizedBox(height: 10),
        OutlineButton(
          '앨범에 저장',
          icon: Icons.download_outlined,
          onPressed: _busy ? null : () => _run(ImageOut.saveToGallery, ok: '갤러리의 "골목대장" 앨범에 저장했어요'),
        ),
      ]),
    );
  }
}

/// 스티커 카드 (320×400 고정 크기). 사진이 있으면 사진 위에 스티커, 없으면 큰 스티커.
class SpotCard extends StatelessWidget {
  const SpotCard({super.key, required this.spot, this.area, this.showMemo = true});
  final Spot spot;
  final String? area;
  final bool showMemo;

  @override
  Widget build(BuildContext context) {
    final memo = showMemo ? spot.memo : '';
    return Container(
      width: _ShareCardScreenState.cardW,
      height: _ShareCardScreenState.cardH,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.cream,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: C.ink, width: 3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 사진 + 스티커
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: C.peach,
              child: Stack(fit: StackFit.expand, children: [
                if (spot.photo != null) SpotPhoto(spot.photo!),
                Align(
                  alignment: spot.photo != null ? Alignment.bottomRight : Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: StickerImg(spot.stickerId, size: spot.photo != null ? 84 : 150),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(spot.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: jua(24)),
        if (memo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(memo, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.ink, height: 1.45)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.place, size: 15, color: C.orange),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              [if (area != null) area!, formatDate(spot.createdAt)].join(' · '),
              style: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600),
            ),
          ),
          const StickerImg('c13', size: 26),
          const SizedBox(width: 4),
          Text('골목대장', style: jua(17)),
        ]),
      ]),
    );
  }
}
