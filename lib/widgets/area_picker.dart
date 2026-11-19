import 'dart:async';

import 'package:flutter/material.dart';

import '../data/places.dart';
import '../data/store.dart';
import '../theme.dart';
import 'ui.dart';

/// 내 동네 고르기: 전국 동·읍·면 검색 + 현재 위치로 찾기 + 직접 입력
/// 회원가입(①-G)과 프로필의 "내 동네 바꾸기"에서 같이 쓴다.
class AreaPicker extends StatefulWidget {
  const AreaPicker({super.key, required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<AreaPicker> createState() => _AreaPickerState();
}

class _AreaPickerState extends State<AreaPicker> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Place> _results = [];
  Place? _here;
  bool _searching = false;
  bool _locating = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _findHere(askPermission: false));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _findHere({bool askPermission = true}) async {
    final s = StoreScope.read(context);
    setState(() => _locating = true);
    if (askPermission || s.lastPos == null) {
      final r = askPermission ? await s.locate() : LocateResult.ok;
      if (r != LocateResult.ok && mounted) toast(context, '위치를 켜면 지금 있는 동네를 찾아 드려요');
    }
    final p = s.lastPos;
    final place = p == null ? null : await Places.reverse(p.lat, p.lng);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _here = place;
    });
    if (askPermission && place == null && p != null) toast(context, '지금 위치의 동네 이름을 찾지 못했어요. 이름으로 검색해 주세요');
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    // 지도 서버 이용 규칙(1초에 한 번)에 맞춰 입력을 멈추고 0.7초 뒤에 찾는다
    _debounce = Timer(const Duration(milliseconds: 700), () => _search(v));
  }

  Future<void> _search(String v) async {
    if (v.trim().length < 2) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    final r = await Places.search(v);
    if (!mounted || v != _q.text) return;
    setState(() {
      _searching = false;
      _searched = true;
      _results = r;
    });
  }

  Widget _tile(String name, {IconData icon = Icons.place_outlined, String? sub}) {
    final on = name == widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        shadow: false,
        color: on ? C.mint : C.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => widget.onSelected(name),
        child: Row(children: [
          Icon(icon, color: on ? C.forest : C.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              if (sub != null) Text(sub, style: TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
          if (on) Icon(Icons.check_circle, color: C.forest),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typed = _q.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlineButton(
        _locating ? '지금 위치 찾는 중…' : '현재 위치로 내 동네 찾기',
        icon: Icons.my_location,
        height: 50,
        onPressed: _locating ? null : () => _findHere(),
      ),
      if (_here != null) ...[
        const SizedBox(height: 10),
        _tile(_here!.name, icon: Icons.my_location, sub: '지금 있는 곳'),
      ],
      const SizedBox(height: 14),
      TextField(
        controller: _q,
        onChanged: (v) {
          setState(() {});
          _onQuery(v);
        },
        textInputAction: TextInputAction.search,
        onSubmitted: _search,
        decoration: InputDecoration(
          hintText: '동·읍·면 이름으로 찾기 (예: 연남동, 해운대)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null,
        ),
      ),
      const SizedBox(height: 12),
      for (final p in _results) _tile(p.name),
      if (_searched && _results.isEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('찾는 동네가 없어요. 이름을 조금 바꿔 보거나, 아래처럼 그대로 쓸 수 있어요.', style: TextStyle(fontSize: 13, color: C.muted)),
        ),
      // 검색이 안 되거나 인터넷이 없을 때: 입력한 이름 그대로 쓰기
      if (typed.length >= 2 && !_results.any((p) => p.name == typed))
        _tile(typed, icon: Icons.edit_location_alt_outlined, sub: '입력한 이름 그대로 쓰기 (검색 결과로 고르는 게 리더보드에 더 정확해요)'),
      if (widget.selected.isNotEmpty && widget.selected != _here?.name && !_results.any((p) => p.name == widget.selected) && widget.selected != typed)
        _tile(widget.selected, sub: '지금 고른 동네'),
      const SizedBox(height: 4),
      Text('동네 이름 © OpenStreetMap 기여자', style: TextStyle(fontSize: 11, color: C.muted)),
    ]);
  }
}

/// 프로필에서 "내 동네 바꾸기"
class AreaPickerScreen extends StatefulWidget {
  const AreaPickerScreen({super.key, required this.current});
  final String current;

  @override
  State<AreaPickerScreen> createState() => _AreaPickerScreenState();
}

class _AreaPickerScreenState extends State<AreaPickerScreen> {
  late String _sel = widget.current;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('내 동네 바꾸기')),
        body: SafeArea(
          top: false,
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                Text('동네 리더보드와 골목 피드가 이 동네 기준으로 보여요', style: TextStyle(fontSize: 13, color: C.muted)),
                const SizedBox(height: 14),
                AreaPicker(selected: _sel, onSelected: (v) => setState(() => _sel = v)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PrimaryButton('이 동네로 할게요', onPressed: _sel.isEmpty || _sel == widget.current ? null : () => Navigator.of(context).pop(_sel)),
            ),
          ]),
        ),
      );
}
