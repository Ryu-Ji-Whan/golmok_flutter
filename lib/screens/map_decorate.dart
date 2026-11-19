import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../data/models.dart';
import '../data/stickers.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/cartoon_map.dart';
import '../widgets/ui.dart';
import 'walk.dart' show buildMarks;

/// ②-4 내 지도 꾸미기: 내 지도에 스티커·글씨를 붙인다 (나만 보임)
/// - 스티커를 누르면 지금 보고 있는 지도 가운데에 붙는다
/// - 붙인 것을 누르면 고르고, 끌어서 옮기고, 아래 버튼으로 크기를 바꾸거나 지운다
class MapDecorateScreen extends StatefulWidget {
  const MapDecorateScreen({super.key});

  @override
  State<MapDecorateScreen> createState() => _MapDecorateScreenState();
}

class _MapDecorateScreenState extends State<MapDecorateScreen> {
  static const maxDecos = 50;

  final _map = MapHandle();
  final _text = TextEditingController();
  late List<MapDeco> _decos;
  late LatLng _center;
  String? _sel;
  int _tab = 0; // 0 = 스티커, 1 = 글씨
  StickerCategory? _cat;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    final s = StoreScope.read(context);
    // 저장하기 전까지는 사본을 고친다
    _decos = [for (final d in s.decos) MapDeco.fromJson(d.toJson())];
    _center = s.center;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _ready() async {
    final s = StoreScope.read(context);
    await _map.setExplored(s.explored);
    await _map.setOldPaths([for (final w in s.walks) w.path]);
    await _map.setMarks(buildMarks(s));
    await _map.setMe(s.center);
    await _show();
    await _map.goTo(_center, zoom: 16.5);
  }

  Future<void> _show() => _map.setDecos(_decos, editing: true, selected: _sel);

  MapDeco? get _selected {
    for (final d in _decos) {
      if (d.id == _sel) return d;
    }
    return null;
  }

  void _onEvent(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'move':
        _center = LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
      case 'mapTap':
        if (_sel != null) {
          setState(() => _sel = null);
          _show();
        }
      case 'decoTap':
        if (_sel != m['id']) {
          setState(() => _sel = m['id'] as String);
          _show();
        }
      case 'decoMove':
        for (final d in _decos) {
          if (d.id == m['id']) {
            d.lat = (m['lat'] as num).toDouble();
            d.lng = (m['lng'] as num).toDouble();
          }
        }
        setState(() {
          _sel = m['id'] as String;
          _changed = true;
        });
        _show();
    }
  }

  void _add({String? sticker, String? text}) {
    if (_decos.length >= maxDecos) {
      toast(context, '꾸미기는 $maxDecos개까지 붙일 수 있어요');
      return;
    }
    // 같은 자리에 겹치지 않게 조금씩 비켜서
    final k = _decos.length % 5 - 2;
    final d = MapDeco(
      id: newId('deco'),
      lat: _center.lat + k * 0.00006,
      lng: _center.lng + k * 0.00008,
      sticker: sticker,
      text: text,
      size: sticker != null ? 64 : 60,
    );
    setState(() {
      _decos.add(d);
      _sel = d.id;
      _changed = true;
    });
    _show();
  }

  void _addText() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _add(text: t);
    _text.clear();
    FocusScope.of(context).unfocus();
  }

  void _resize(double f) {
    final d = _selected;
    if (d == null) return;
    setState(() {
      d.size = (d.size * f).clamp(28.0, 180.0);
      _changed = true;
    });
    _show();
  }

  void _remove() {
    final d = _selected;
    if (d == null) return;
    setState(() {
      _decos.remove(d);
      _sel = null;
      _changed = true;
    });
    _show();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    await StoreScope.read(context).saveDecos(_decos);
    nav.pop(true);
  }

  Future<bool> _confirmLeave() async {
    if (!_changed) return true;
    return confirm(context, '꾸미기를 그만할까요?', '저장하지 않은 꾸미기는 사라져요.', ok: '그만하기', danger: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final mine = s.owned.map(stickerOf).where((x) => _cat == null || x.category == _cat).toList()..sort((a, b) => a.id.compareTo(b.id));
    final cats = StickerCategory.values.where((c) => s.owned.any((id) => stickerOf(id).category == c)).toList();
    final top = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: CartoonMap(handle: _map, onReady: _ready, onEvent: _onEvent)),
              // 위 막대: 뒤로 · 제목 · 완료
              Positioned(
                left: 16,
                right: 16,
                top: top + 8,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999), boxShadow: cardShadow),
                  child: Row(children: [
                    IconButton(
                      tooltip: '뒤로',
                      icon: const Icon(Icons.chevron_left, size: 28),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        if (await _confirmLeave()) nav.pop();
                      },
                    ),
                    Expanded(child: Text('내 지도 꾸미기', textAlign: TextAlign.center, style: jua(20, color: C.ink))),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(backgroundColor: C.forest, shape: const StadiumBorder()),
                      child: const Text('완료', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4),
                  ]),
                ),
              ),
              // 고른 것 고치기 / 도움말
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Center(
                  child: _sel == null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(999)),
                          child: Text('스티커를 누르면 지도 가운데에 붙어요', style: TextStyle(color: C.white, fontSize: 13)),
                        )
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          _toolBtn(Icons.remove, '작게', () => _resize(1 / 1.2)),
                          _toolBtn(Icons.add, '크게', () => _resize(1.2)),
                          _toolBtn(Icons.delete_outline, '삭제', _remove, color: C.danger),
                        ]),
                ),
              ),
            ]),
          ),
          // 아래 판: 스티커 / 글씨
          Container(
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet)),
              boxShadow: cardShadow,
            ),
            padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                _tabBtn(0, '스티커'),
                _tabBtn(1, '글씨'),
                const Spacer(),
                Text('꾸미기 ${_decos.length}/$maxDecos', style: TextStyle(fontSize: 13, color: C.muted)),
              ]),
              Divider(height: 1, color: C.lineSoft),
              const SizedBox(height: 10),
              if (_tab == 0) ...[
                SizedBox(
                  height: 38,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _catChip(null, '전체'),
                    for (final c in cats) _catChip(c, categoryLabel[c]!),
                  ]),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  child: GridView.count(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final st in mine)
                        Material(
                          color: C.cream,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _add(sticker: st.id),
                            child: Padding(padding: const EdgeInsets.all(6), child: StickerImg(st.id)),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLength: 12,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addText(),
                      decoration: const InputDecoration(hintText: '예: 고양이 골목, 단골 빵집', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: PrimaryButton('붙이기', height: 50, onPressed: _addText),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('글씨는 12자까지, 붙인 뒤 끌어서 옮길 수 있어요', style: TextStyle(fontSize: 12, color: C.muted)),
                const SizedBox(height: 8),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tabBtn(int i, String label) => InkWell(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          margin: const EdgeInsets.only(right: 18),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == i ? C.forest : Colors.transparent, width: 3))),
          child: Text(label, style: jua(20, color: _tab == i ? C.forest : C.muted)),
        ),
      );

  Widget _toolBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(
            backgroundColor: C.white,
            foregroundColor: color ?? C.ink,
            elevation: 2,
            shadowColor: C.shadow,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      );

  Widget _catChip(StickerCategory? c, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _cat == c,
          showCheckmark: false,
          selectedColor: C.forest,
          backgroundColor: C.white,
          labelStyle: TextStyle(color: _cat == c ? C.white : C.ink, fontWeight: FontWeight.w700),
          shape: StadiumBorder(side: BorderSide(color: C.line)),
          onSelected: (_) => setState(() => _cat = c),
        ),
      );
}
