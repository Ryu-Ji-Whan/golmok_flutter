import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/stickers.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'campaign.dart';
import 'stores.dart';
import 'town.dart';

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
        Row(children: [
          Expanded(
            child: _Entry(
              icon: Icons.flag_outlined,
              title: '스탬프 투어',
              sub: '${s.stamps.length}/${Campaign.spots.length} 찍음',
              color: C.mint,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CampaignScreen())),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Entry(
              icon: Icons.storefront_outlined,
              title: '제휴 가게',
              sub: '쿠폰 ${s.coupons.where((c) => c.usedAt == null).length}장',
              color: C.peach,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoresScreen())),
            ),
          ),
        ]),
        const SectionTitle('스티커 팩'),
        for (final p in packs) _PackCard(pack: p),
        const SizedBox(height: 8),
        const Text('데모 버전이라 결제 없이 받을 수 있어요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted)),
      ]),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.icon, required this.title, required this.sub, required this.color, required this.onTap});
  final IconData icon;
  final String title, sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CardBox(
        color: color,
        shadow: false,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: C.forest),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
        ]),
      );
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
        final ok = pack.id == 'campaign' ? s.campaignDone : myRank(s) <= 3;
        final claimed = s.rewards.contains(pack.id);
        label = claimed ? '받음' : ok ? '보상 받기' : '조건 미달성';
        action = ok && !claimed ? () => s.claimReward(pack.id, pack.stickers) : null;
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
