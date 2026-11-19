import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/cartoon_map.dart';
import '../widgets/ui.dart';
import 'walk.dart' show buildMarks;

/// 친구에게 받은 스티커: 내 지도에서 그 자리를 보여 주고, "받기"를 누르면 스티커가 날아와 콩 붙는다.
/// 받은 순간부터 내 기록이 된다 (보낸 친구가 원래 기록을 지워도 남음).
class GiftReceiveScreen extends StatefulWidget {
  const GiftReceiveScreen({super.key});

  @override
  State<GiftReceiveScreen> createState() => _GiftReceiveScreenState();
}

class _GiftReceiveScreenState extends State<GiftReceiveScreen> {
  final _map = MapHandle();
  bool _busy = false;
  String? _landed; // 방금 받은 스티커를 보낸 친구 (받은 뒤 화면)
  int _total = 0;

  Gift? get _gift {
    final g = StoreScope.read(context).gifts;
    return g.isEmpty ? null : g.first;
  }

  Future<void> _ready() async {
    final s = StoreScope.read(context);
    _total = s.gifts.length;
    await _map.setExplored(s.explored);
    await _map.setMarks(buildMarks(s));
    await _map.setDecos(s.decos);
    await _map.setMe(s.center);
    final g = _gift;
    await _map.goTo(g?.pos ?? s.center, zoom: 16.5);
  }

  Future<void> _accept(Gift g) async {
    setState(() => _busy = true);
    final s = StoreScope.read(context);
    final sp = await s.acceptGift(g);
    await _map.setMarks(buildMarks(s));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await _map.stamp(sp.id, fly: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _landed = g.fromName;
    });
  }

  Future<void> _decline(Gift g) async {
    final ok = await confirm(context, '이 스티커를 받지 않을까요?', '${g.fromName}님이 보낸 스티커가 사라져요. 보낸 친구에게는 알리지 않아요.', ok: '받지 않기', danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    await StoreScope.read(context).declineGift(g);
    if (!mounted) return;
    setState(() => _busy = false);
    _next();
  }

  void _next() {
    final g = _gift;
    if (g == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _landed = null);
    _map.goTo(g.pos, zoom: 16.5);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final g = _gift;
    final left = s.gifts.length;
    return Scaffold(
      appBar: AppBar(title: Text(_total > 1 ? '받은 스티커 (${_total - left + (_landed == null ? 1 : 0)}/$_total)' : '받은 스티커')),
      body: Stack(children: [
        Positioned.fill(child: CartoonMap(handle: _map, onReady: _ready)),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _landed != null
                  ? _doneCard(left)
                  : g == null
                      ? _emptyCard()
                      : _giftCard(g),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _giftCard(Gift g) => CardBox(
        key: ValueKey(g.id),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(g.fromCharacter, size: 40),
            const SizedBox(width: 10),
            Expanded(child: Text('${g.fromName}님이 스티커를 보냈어요', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            StickerImg(g.stickerId, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: jua(22), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (g.memo.isNotEmpty) Text(g.memo, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.muted)),
                Text('${formatDate(g.madeAt)}에 남긴 기록${g.photo != null ? ' · 사진 있음' : ''}', style: const TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('지도 가운데가 친구가 기록한 자리예요.', style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlineButton('받지 않기', height: 50, color: C.muted, onPressed: _busy ? null : () => _decline(g))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: PrimaryButton(_busy ? '받는 중…' : '받기', height: 50, icon: Icons.download_done, color: C.orange, onPressed: _busy ? null : () => _accept(g))),
          ]),
        ]),
      );

  Widget _doneCard(int left) => CardBox(
        key: const ValueKey('done'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('내 지도에 콩 붙었어요!', style: jua(24)),
          const SizedBox(height: 4),
          Text('$_landed님이 보낸 스티커는 이제 내 기록이에요.\n"내 지도"에서 언제든 보고, 지울 수도 있어요.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
          const SizedBox(height: 12),
          PrimaryButton(left > 0 ? '다음 스티커 보기 ($left)' : '확인', height: 50, onPressed: _next),
        ]),
      );

  Widget _emptyCard() => CardBox(
        key: const ValueKey('empty'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('받을 스티커가 없어요', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          PrimaryButton('확인', height: 50, onPressed: () => Navigator.pop(context)),
        ]),
      );
}
