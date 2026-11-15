import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class _Row {
  const _Row(this.name, this.character, this.cells, this.me);
  final String name;
  final String character;
  final int cells;
  final bool me;
}

/// 리더보드 순위 (이웃 예시 + 나)
List<_Row> leaderboard(AppStore s) {
  final rows = [
    for (final n in neighbors) _Row(n.name, n.character, n.cells, false),
    _Row(s.profile?.nickname ?? '나', s.profile?.characterId ?? 'a00', s.weeklyCells, true),
  ]..sort((a, b) => b.cells.compareTo(a.cells));
  return rows;
}

int myRank(AppStore s) => leaderboard(s).indexWhere((r) => r.me) + 1;

/// ⑤ 동네 리더보드
class TownTab extends StatelessWidget {
  const TownTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final rows = leaderboard(s);
    final rank = myRank(s);
    final area = (s.profile?.areaName ?? '').split(' ').last;
    final leaderPack = packs.firstWhere((p) => p.id == 'leader');
    final claimed = s.rewards.contains('leader');
    return Scaffold(
      appBar: AppBar(title: Text('$area 리더보드')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        CardBox(
          color: C.forest,
          child: Row(children: [
            Avatar(s.profile?.characterId ?? 'a00', size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('이번 주 내 순위', style: TextStyle(fontSize: 13, color: C.mint)),
                Text('$rank위 · ${s.weeklyCells}칸', style: jua(28, color: C.white)),
                Text(rank <= 3 ? '동네 대장 스티커를 받을 수 있어요!' : '${rows[2].cells - s.weeklyCells + 1}칸 더 밝히면 3위예요',
                    style: const TextStyle(fontSize: 12, color: C.mint)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // 1~3위 단상
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final i in [1, 0, 2])
            if (i < rows.length) Expanded(child: _Podium(row: rows[i], place: i + 1)),
        ]),
        const SectionTitle('전체 순위', trailing: Text('이번 주 밝힌 칸', style: TextStyle(fontSize: 12, color: C.muted))),
        for (var i = 0; i < rows.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: rows[i].me ? C.mint : C.white,
              borderRadius: BorderRadius.circular(R.input),
              border: rows[i].me ? Border.all(color: C.leaf) : null,
            ),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${i + 1}', style: jua(18, color: i < 3 ? C.orangeText : C.muted))),
              Avatar(rows[i].character, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text(rows[i].me ? '${rows[i].name} (나)' : rows[i].name, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('${rows[i].cells}칸', style: const TextStyle(fontWeight: FontWeight.w700, color: C.forest)),
            ]),
          ),
        const SizedBox(height: 16),
        CardBox(
          color: C.peach,
          shadow: false,
          child: Row(children: [
            for (final id in leaderPack.stickers) StickerImg(id, size: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(leaderPack.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(leaderPack.howToGet ?? '', style: const TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
            FilledButton(
              onPressed: rank <= 3 && !claimed ? () => s.claimReward('leader', leaderPack.stickers) : null,
              style: FilledButton.styleFrom(backgroundColor: C.forest),
              child: Text(claimed ? '받음' : '받기'),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('이웃 점수는 예시예요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted)),
      ]),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.row, required this.place});
  final _Row row;
  final int place;

  @override
  Widget build(BuildContext context) {
    final h = place == 1 ? 96.0 : place == 2 ? 72.0 : 56.0;
    return Column(children: [
      Avatar(row.character, size: place == 1 ? 64 : 52),
      const SizedBox(height: 4),
      Text(row.me ? '나' : row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Container(
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: place == 1 ? C.orange : C.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          border: Border.all(color: C.ink, width: 2),
        ),
        alignment: Alignment.center,
        child: Text('$place', style: jua(28, color: C.ink)),
      ),
    ]);
  }
}
