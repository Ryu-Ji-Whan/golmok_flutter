import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/geo.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// ⑦-2 제휴 가게 이벤트 + 내 쿠폰
class StoresScreen extends StatelessWidget {
  const StoresScreen({super.key});

  Future<void> _visit(BuildContext context, Store st) async {
    final s = StoreScope.read(context);
    final c = await s.visitStore(st);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: C.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.big)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          StickerImg(st.sticker, size: 110),
          const SizedBox(height: 8),
          Text('${st.name} 방문 인증!', style: jua(22)),
          const SizedBox(height: 6),
          Text('스티커와 쿠폰을 받았어요\n${c.title}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('좋아요', style: TextStyle(color: C.forest, fontWeight: FontWeight.w700)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final active = s.coupons.where((c) => c.usedAt == null).toList();
    final used = s.coupons.where((c) => c.usedAt != null).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('우리 동네 가게')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        for (final st in stores)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardBox(
              child: Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(R.card)),
                  alignment: Alignment.center,
                  child: StickerImg(st.sticker, size: 54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(st.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      if (st.isNew) ...[const SizedBox(width: 6), const Pill('NEW', bg: C.peach, fg: C.orangeText)],
                    ]),
                    Text('${st.category} · ${_dist(s, st)}', style: const TextStyle(fontSize: 12, color: C.muted)),
                    Text(st.benefit, style: const TextStyle(fontSize: 12, color: C.leafText)),
                  ]),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: s.visitedStores.contains(st.id) ? null : () => _visit(context, st),
                  style: FilledButton.styleFrom(backgroundColor: C.forest, disabledBackgroundColor: C.sand, disabledForegroundColor: C.muted),
                  child: Text(s.visitedStores.contains(st.id) ? '방문함' : '방문 인증'),
                ),
              ]),
            ),
          ),
        SectionTitle('내 쿠폰 ${active.length}장'),
        if (s.coupons.isEmpty) const Text('가게에서 방문 인증을 하면 쿠폰이 생겨요.', style: TextStyle(fontSize: 13, color: C.muted)),
        for (final c in [...active, ...used])
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.usedAt == null ? C.peach : C.sand,
              borderRadius: BorderRadius.circular(R.card),
              border: Border.all(color: c.usedAt == null ? C.orange : C.line, width: 1.5),
            ),
            child: Row(children: [
              Icon(Icons.confirmation_number_outlined, color: c.usedAt == null ? C.orangeText : C.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.title, style: TextStyle(fontWeight: FontWeight.w700, color: c.usedAt == null ? C.ink : C.muted)),
                  Text(c.usedAt == null ? '받은 날 ${formatDate(c.issuedAt)}' : '사용함 ${formatDate(c.usedAt!)}', style: const TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
              if (c.usedAt == null)
                TextButton(
                  onPressed: () async {
                    if (await confirm(context, '쿠폰을 쓸까요?', '가게 직원에게 이 화면을 보여 주고 눌러 주세요.', ok: '사용하기')) {
                      await s.useCoupon(c.id);
                    }
                  },
                  child: const Text('사용하기', style: TextStyle(color: C.orangeText, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
      ]),
    );
  }

  String _dist(AppStore s, Store st) {
    final d = s.distanceTo(s.storePos(st));
    return d == null ? '거리 모름' : formatDistance(d);
  }
}
