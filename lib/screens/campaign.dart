import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/geo.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// ⑦-1 기관 캠페인 (동네 스탬프 투어)
class CampaignScreen extends StatelessWidget {
  const CampaignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final done = s.stamps.length;
    final total = Campaign.spots.length;
    final pack = packs.firstWhere((p) => p.id == 'campaign');
    final claimed = s.rewards.contains('campaign');
    return Scaffold(
      appBar: AppBar(title: const Text('스탬프 투어')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        CardBox(
          color: C.forest,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(Campaign.organizer, style: TextStyle(fontSize: 12, color: C.mint)),
            const SizedBox(height: 2),
            Text(Campaign.title, style: jua(26, color: C.white)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: done / total, minHeight: 8, color: C.orange, backgroundColor: C.leaf),
            ),
            const SizedBox(height: 6),
            Text('$done / $total곳 · 완주하면 ${Campaign.reward}', style: const TextStyle(fontSize: 12, color: C.mint)),
          ]),
        ),
        const SectionTitle('스탬프 장소'),
        for (final c in Campaign.spots) _SpotRow(spot: c),
        const SizedBox(height: 12),
        CardBox(
          color: C.peach,
          shadow: false,
          child: Row(children: [
            for (final id in pack.stickers) StickerImg(id, size: 52),
            const SizedBox(width: 10),
            const Expanded(child: Text('완주 보상', style: TextStyle(fontWeight: FontWeight.w700))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.forest),
              onPressed: s.campaignDone && !claimed
                  ? () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await s.claimReward('campaign', pack.stickers,
                          coupon: Coupon(id: newId('cp'), storeId: 'cafe', title: '스탬프 투어 완주 기념 음료 쿠폰 (데모)', issuedAt: DateTime.now()));
                      messenger.showSnackBar(const SnackBar(content: Text('완주 보상을 받았어요! 쿠폰은 제휴 가게에서 볼 수 있어요')));
                    }
                  : null,
              child: Text(claimed ? '받음' : '받기'),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('스팟은 처음 위치를 잡은 곳 주변 ${Campaign.radiusM.round()}m 안에서 찍을 수 있어요. 데모라서 멀리 있어도 "데모로 찍기"가 돼요.',
            style: const TextStyle(fontSize: 12, color: C.muted, height: 1.5)),
      ]),
    );
  }
}

class _SpotRow extends StatelessWidget {
  const _SpotRow({required this.spot});
  final CampaignSpot spot;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final stamped = s.stamps.contains(spot.id);
    final d = s.distanceTo(s.campaignPos(spot));
    final near = d != null && d <= Campaign.radiusM;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: stamped ? C.orange : C.cream,
              shape: BoxShape.circle,
              border: Border.all(color: stamped ? C.orangeText : C.line, width: 2),
            ),
            alignment: Alignment.center,
            child: stamped ? const Icon(Icons.check, color: C.white, size: 28) : const StickerImg('c04', size: 38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(spot.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(d == null ? '위치를 켜면 거리가 보여요' : '여기서 ${formatDistance(d)}', style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
          if (!stamped)
            TextButton(
              onPressed: () => s.stamp(spot.id),
              child: Text(near ? '스탬프 찍기' : '데모로 찍기', style: const TextStyle(fontWeight: FontWeight.w700, color: C.forest)),
            ),
        ]),
      ),
    );
  }
}
