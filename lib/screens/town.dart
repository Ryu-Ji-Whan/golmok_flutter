import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/geo.dart';
import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

String _short(String area) => area.split(' ').last;

/// ⑤ 동네 리더보드 — 걸은 곳 기준
/// · 기본은 "지금 있는 동네": 그 동네에서 이번 주 실제로 걸은 거리로 순위
/// · "내 동네"(프로필에서 정한 주 생활 동네)와 "이번 주 내가 걸은 동네"도 골라 볼 수 있다
/// · 동네 대장 보상은 내 동네에서만
class TownTab extends StatefulWidget {
  const TownTab({super.key});

  @override
  State<TownTab> createState() => _TownTabState();
}

class _TownTabState extends State<TownTab> {
  String? _here; // 지금 있는 동네
  String? _viewing; // 보고 있는 동네
  bool _pickedByHand = false; // 사용자가 다른 동네를 골랐으면 지금 위치로 바꾸지 않는다
  bool _locating = false;
  bool _loading = false;
  List<RemoteRank>? _rows;
  List<MyArea>? _mine;

  @override
  void initState() {
    super.initState();
    final s = StoreScope.read(context);
    _here = s.currentArea;
    _viewing = _here ?? s.profile?.areaName;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final s = StoreScope.read(context);
    setState(() => _locating = true);
    final here = await s.refreshCurrentArea();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _here = here;
      if (!_pickedByHand && here != null) _viewing = here;
    });
    await _load();
  }

  Future<void> _load() async {
    final area = _viewing;
    setState(() => _loading = true);
    final rows = area == null ? <RemoteRank>[] : await Remote.areaLeaderboard(area);
    final mine = await Remote.myAreas();
    if (!mounted || area != _viewing) return;
    setState(() {
      _loading = false;
      _rows = rows;
      _mine = mine;
    });
  }

  void _view(String area) {
    if (area == _viewing) return;
    setState(() {
      _viewing = area;
      _pickedByHand = area != _here;
      _rows = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final home = s.profile?.areaName;
    return Scaffold(
      appBar: AppBar(title: const Text('동네 리더보드')),
      body: !Remote.signedIn
          ? _message('로그인하면 걸은 동네의 이웃과\n이번 주 순위를 겨룰 수 있어요')
          : RefreshIndicator(
              color: C.forest,
              onRefresh: _refresh,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                // 어느 동네를 볼지
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip(
                    icon: Icons.my_location,
                    label: _here != null ? '지금 여기 · ${_short(_here!)}' : (_locating ? '지금 위치 확인 중…' : '지금 위치를 몰라요'),
                    selected: _here != null && _viewing == _here,
                    onTap: _here == null ? _refresh : () => _view(_here!),
                  ),
                  if (home != null && home.isNotEmpty && home != _here)
                    _chip(icon: Icons.home_outlined, label: '내 동네 · ${_short(home)}', selected: _viewing == home, onTap: () => _view(home)),
                ]),
                const SizedBox(height: 14),
                if (_viewing == null)
                  _message('위치를 켜거나 프로필에서 내 동네를 정하면\n그 동네 순위를 볼 수 있어요')
                else ...[
                  _header(s, _viewing!),
                  const SizedBox(height: 16),
                  ..._board(),
                ],
                _myAreas(),
                if (home != null && _viewing == home) _reward(s),
                const SizedBox(height: 12),
                CardBox(
                  padding: EdgeInsets.zero,
                  shadow: false,
                  child: SwitchListTile(
                    value: s.hideRank,
                    onChanged: (v) async {
                      await s.setHideRank(v);
                      _load();
                    },
                    activeTrackColor: C.leaf,
                    title: const Text('리더보드에 내 이름 숨기기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: const Text('켜면 다른 사람 순위표에 내가 안 나와요', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '이번 주에 그 동네에서 걸은 거리로 순위를 매겨요. 다른 사람에게는 닉네임과 거리만 보이고, 위치나 경로는 보이지 않아요. 당겨서 새로고침할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: C.muted, height: 1.5),
                ),
              ]),
            ),
    );
  }

  Widget _chip({required IconData icon, required String label, required bool selected, required VoidCallback onTap}) => ChoiceChip(
        avatar: Icon(icon, size: 18, color: selected ? C.white : C.forest),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: C.forest,
        backgroundColor: C.white,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: selected ? C.white : C.forest),
        onSelected: (_) => onTap(),
      );

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          const StickerImg('a04', size: 110),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: C.muted, height: 1.6)),
        ]),
      );

  Widget _header(AppStore s, String area) {
    final rows = _rows ?? const <RemoteRank>[];
    final i = rows.indexWhere((r) => r.isMe);
    final me = i >= 0 ? rows[i] : null;
    return CardBox(
      color: C.forest,
      child: Row(children: [
        Avatar(s.profile?.characterId ?? 'a00', size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(area, style: TextStyle(fontSize: 12, color: C.mint)),
            Text(me == null ? '아직 0m' : '${i + 1}위 · ${formatDistance(me.meters.toDouble())}', style: jua(28, color: C.white)),
            Text(
              _rows == null
                  ? '순위를 불러오는 중이에요'
                  : me == null
                      ? '이번 주 이 동네를 아직 안 걸었어요. 산책하면 순위에 들어가요!'
                      : rows.length == 1
                          ? '이번 주 이 동네를 걸은 사람은 나뿐이에요'
                          : '이번 주 이 동네를 걸은 ${rows.length}명 중',
              style: TextStyle(fontSize: 12, color: C.mint),
            ),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _board() {
    final rows = _rows;
    if (rows == null) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: _loading ? CircularProgressIndicator(color: C.forest) : Text('순위를 불러오지 못했어요. 당겨서 다시 해 보세요', style: TextStyle(color: C.muted))),
        ),
      ];
    }
    if (rows.isEmpty) return [_message('이번 주 이 동네를 걸은 사람이 아직 없어요\n첫 번째 골목대장이 되어 보세요!')];
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final i in [1, 0, 2])
          if (i < rows.length) Expanded(child: _Podium(row: rows[i], place: i + 1)),
      ]),
      SectionTitle('전체 순위', trailing: Text('이번 주 걸은 거리', style: TextStyle(fontSize: 12, color: C.muted))),
      for (var i = 0; i < rows.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: rows[i].isMe ? C.mint : C.white,
            borderRadius: BorderRadius.circular(R.input),
            border: rows[i].isMe ? Border.all(color: C.leaf) : null,
          ),
          child: Row(children: [
            SizedBox(width: 28, child: Text('${i + 1}', style: jua(18, color: i < 3 ? C.orangeText : C.muted))),
            Avatar(rows[i].character, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Text(rows[i].isMe ? '${rows[i].nickname} (나)' : rows[i].nickname, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(formatDistance(rows[i].meters.toDouble()), style: TextStyle(fontWeight: FontWeight.w700, color: C.forest)),
          ]),
        ),
    ];
  }

  Widget _myAreas() {
    final mine = _mine;
    if (mine == null || mine.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('이번 주 내가 걸은 동네'),
      for (final a in mine)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CardBox(
            shadow: false,
            color: a.area == _viewing ? C.mint : C.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => _view(a.area),
            child: Row(children: [
              Icon(Icons.place_outlined, color: a.area == _viewing ? C.forest : C.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_short(a.area), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(a.area, style: TextStyle(fontSize: 11, color: C.muted)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${a.rank}위', style: jua(20, color: a.rank <= 3 ? C.orangeText : C.forest)),
                Text('${a.people}명 중 · ${formatDistance(a.meters.toDouble())}', style: TextStyle(fontSize: 11, color: C.muted)),
              ]),
            ]),
          ),
        ),
    ]);
  }

  /// 내 동네 대장 보상: 이웃이 3명 이상 있는 내 동네에서 3위 안
  Widget _reward(AppStore s) {
    final rows = _rows ?? const <RemoteRank>[];
    final rank = rows.indexWhere((r) => r.isMe) + 1;
    final ok = rows.length >= 4 && rank > 0 && rank <= 3;
    final pack = packs.firstWhere((p) => p.id == 'leader');
    final claimed = s.rewards.contains('leader');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CardBox(
        color: C.peach,
        shadow: false,
        child: Row(children: [
          for (final id in pack.stickers) StickerImg(id, size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pack.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(rows.length < 4 ? '내 동네 이웃이 4명 이상 모이면 경쟁이 시작돼요' : '내 동네 이번 주 3위 안에 들면 받아요',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
          FilledButton(
            onPressed: ok && !claimed ? () => s.claimReward('leader', pack.stickers) : null,
            style: FilledButton.styleFrom(backgroundColor: C.forest),
            child: Text(claimed ? '받음' : '받기'),
          ),
        ]),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.row, required this.place});
  final RemoteRank row;
  final int place;

  @override
  Widget build(BuildContext context) {
    final h = place == 1 ? 96.0 : place == 2 ? 72.0 : 56.0;
    return Column(children: [
      Avatar(row.character, size: place == 1 ? 64 : 52),
      const SizedBox(height: 4),
      Text(row.isMe ? '나' : row.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
