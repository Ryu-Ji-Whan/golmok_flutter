import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/stickers.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// ⑥ 스티커 상점
class ShopTab extends StatelessWidget {
  const ShopTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('스티커 상점'),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Pill('보관함 ${s.owned.length}/${stickers.length}'))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        const SectionTitle('스티커 팩'),
        for (final p in packs) _PackCard(pack: p),
        const SizedBox(height: 8),
        const Text('데모 버전이라 결제 없이 받을 수 있어요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted)),
      ]),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack});
  final Pack pack;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final have = pack.stickers.where(s.owned.contains).length;
    final all = have == pack.stickers.length;
    var label = '';
    VoidCallback? action;
    switch (pack.kind) {
      case PackKind.starter:
      case PackKind.welcome:
        label = all ? '보유 중' : '가입 선물';
        action = null;
      case PackKind.paid:
        label = all ? '보유 중' : '데모로 받기';
        action = all
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                await s.own(pack.stickers);
                messenger.showSnackBar(SnackBar(content: Text('${pack.name}을 받았어요')));
              };
      case PackKind.reward:
        // 동네 대장 보상은 실제 이웃 순위를 아는 "동네" 탭에서 받는다
        label = s.rewards.contains(pack.id) ? '받음' : '동네 탭에서 받기';
        action = null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(pack.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  if (pack.kind == PackKind.reward) const Pill('한정', bg: C.peach, fg: C.orangeText),
                ]),
                Text(pack.howToGet ?? pack.desc, style: const TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
            Text('$have/${pack.stickers.length}', style: const TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(backgroundColor: C.forest, disabledBackgroundColor: C.sand, disabledForegroundColor: C.muted),
              child: Text(label),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final id in pack.stickers)
                Opacity(
                  opacity: s.owned.contains(id) ? 1 : 0.35,
                  child: Padding(padding: const EdgeInsets.only(right: 6), child: StickerImg(id, size: 52)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
