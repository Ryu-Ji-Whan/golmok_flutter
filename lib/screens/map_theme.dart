import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/cartoon_map.dart';
import '../widgets/ui.dart';
import 'walk.dart' show buildMarks;

/// 지도 테마 고르기: 위에서 내 지도로 미리 보고, 아래에서 고른다. 폰에만 저장
class MapThemeScreen extends StatefulWidget {
  const MapThemeScreen({super.key});

  @override
  State<MapThemeScreen> createState() => _MapThemeScreenState();
}

class _MapThemeScreenState extends State<MapThemeScreen> {
  final _map = MapHandle();
  late String _sel = StoreScope.read(context).mapTheme;

  Future<void> _ready() async {
    final s = StoreScope.read(context);
    await _map.setExplored(s.explored);
    await _map.setMarks(buildMarks(s));
    await _map.setMe(s.center);
    await _map.goTo(s.center, zoom: 16);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final changed = _sel != s.mapTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('지도 테마')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(R.big),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.42,
              decoration: BoxDecoration(border: Border.all(color: C.ink, width: 2), borderRadius: BorderRadius.circular(R.big)),
              child: CartoonMap(handle: _map, theme: _sel, onReady: _ready),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Text('테마를 누르면 위 지도가 바로 바뀌어요. 처음 고를 때는 글씨체를 받느라 몇 초 걸릴 수 있어요.',
              style: TextStyle(fontSize: 12, color: C.muted, height: 1.4)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            itemCount: mapThemes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = mapThemes[i];
              final on = t.id == _sel;
              return InkWell(
                borderRadius: BorderRadius.circular(R.card),
                onTap: () => setState(() => _sel = t.id),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: on ? C.mint : C.white,
                    borderRadius: BorderRadius.circular(R.card),
                    border: Border.all(color: on ? C.forest : C.line, width: on ? 2 : 1),
                  ),
                  child: Row(children: [
                    // 대표 색 네 칸
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: GridView.count(
                          crossAxisCount: 2,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [for (final c in t.colors) ColoredBox(color: c)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(t.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          if (t.id == s.mapTheme) ...[const SizedBox(width: 6), const Pill('지금 쓰는 중')],
                        ]),
                        const SizedBox(height: 2),
                        Text(t.desc, style: TextStyle(fontSize: 12, color: C.muted)),
                      ]),
                    ),
                    Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? C.forest : C.line),
                  ]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: PrimaryButton(changed ? '이 테마로 하기' : '지금 쓰는 테마예요', onPressed: !changed
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    await s.setMapTheme(_sel);
                    nav.pop();
                  }),
          ),
        ),
      ]),
    );
  }
}
