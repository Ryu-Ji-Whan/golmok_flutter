import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/geo.dart';
import '../data/models.dart' show MapDeco;
import '../theme.dart';

/// 지도에 올릴 스티커 하나
class MapMark {
  const MapMark({required this.id, required this.pos, required this.sticker, required this.kind, this.label = ''});
  final String id;
  final LatLng pos;
  final String sticker;

  /// spot(내 기록) / stamp(캠페인, 아직) / stamped(캠페인, 찍음) / store(제휴 가게)
  final String kind;
  final String label;

  Map<String, Object> toJson() => {'id': id, 'lng': pos.lng, 'lat': pos.lat, 'sticker': sticker, 'kind': kind, 'label': label};
}

/// 지도에 명령을 보내는 손잡이. 화면이 갖고 있다가 CartoonMap에 넘긴다.
class MapHandle {
  WebViewController? _c;
  bool ready = false;

  Future<void> _js(String fn, List<Object?> args) async {
    final c = _c;
    if (c == null || !ready) return;
    final a = args.map(jsonEncode).join(',');
    try {
      await c.runJavaScript('window.$fn($a)');
    } catch (_) {}
  }

  Future<void> goTo(LatLng p, {double? zoom}) => _js('goTo', [p.lng, p.lat, zoom]);
  Future<void> setFog(bool on) => _js('setFog', [on]);
  Future<void> setExplored(Iterable<String> keys) => _js('setExplored', [keys.toList()]);
  Future<void> addExplored(List<String> keys) => keys.isEmpty ? Future.value() : _js('addExplored', [keys]);
  Future<void> setPath(List<LatLng> path) => _js('setPath', [path.map((p) => p.toLngLat()).toList()]);
  Future<void> setOldPaths(List<List<LatLng>> paths) =>
      _js('setOldPaths', [paths.map((path) => path.map((p) => p.toLngLat()).toList()).toList()]);
  Future<void> setMe(LatLng p) => _js('setMe', [p.lng, p.lat]);
  Future<void> setMarks(List<MapMark> marks) => _js('setSpots', [marks.map((m) => m.toJson()).toList()]);
  Future<void> setWobble(bool on) => _js('setWobble', [on]);

  /// 지도 꾸미기 표시. [editing]이면 눌러서 고르고 끌어서 옮길 수 있다.
  Future<void> setDecos(List<MapDeco> decos, {bool editing = false, String? selected}) =>
      _js('setDecos', [decos.map((d) => d.toJson()).toList(), editing, selected]);
}

/// 만화풍 지도 (assets/map/cartoon_map.html 을 WebView로 띄운다)
class CartoonMap extends StatefulWidget {
  const CartoonMap({super.key, required this.handle, this.onReady, this.onTap, this.onEvent});
  final MapHandle handle;
  final VoidCallback? onReady;

  /// 지도 위 스티커를 눌렀을 때 (kind, id)
  final void Function(String kind, String id)? onTap;

  /// 그 밖의 지도 소식 (move, mapTap, decoTap, decoMove …) 전체
  final void Function(Map<String, dynamic> msg)? onEvent;

  @override
  State<CartoonMap> createState() => _CartoonMapState();
}

class _CartoonMapState extends State<CartoonMap> {
  late final WebViewController _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(C.cream)
      ..addJavaScriptChannel('Golmok', onMessageReceived: _onMessage)
      ..loadFlutterAsset('assets/map/cartoon_map.html');
    widget.handle._c = _c;
  }

  void _onMessage(JavaScriptMessage m) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(m.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'ready':
        widget.handle.ready = true;
        if (mounted) setState(() => _ready = true);
        widget.onReady?.call();
      case 'tap':
        widget.onTap?.call(msg['kind'] as String, msg['id'] as String);
      default:
        widget.onEvent?.call(msg);
    }
  }

  @override
  void dispose() {
    widget.handle.ready = false;
    widget.handle._c = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: WebViewWidget(
            controller: _c,
            gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
          ),
        ),
        if (!_ready)
          Positioned.fill(
            child: ColoredBox(
              color: C.cream,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: C.forest),
                  const SizedBox(height: 12),
                  Text('골목 지도를 그리는 중이에요', style: jua(18, color: C.forest)),
                ]),
              ),
            ),
          ),
      ]);
}
