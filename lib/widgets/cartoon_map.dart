import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/geo.dart';
import '../data/store.dart';
import '../theme.dart';

/// 지도 테마 (assets/map/cartoon_map.html 의 THEMES 와 같은 이름)
class MapTheme {
  const MapTheme(this.id, this.name, this.desc, this.colors);
  final String id, name, desc;

  /// 고르는 화면에 보여 줄 대표 색 (바탕, 건물, 길, 포인트)
  final List<Color> colors;
}

const mapThemes = [
  MapTheme('pastel', '골목 파스텔', '기본 만화풍. 굵은 외곽선과 건물 그림자', [Color(0xFFFFF9ED), Color(0xFFFDE3CC), Color(0xFFFFE19A), Color(0xFF24322C)]),
  MapTheme('night', '밤 산책', '창문마다 불이 켜진 밤 골목, 가로등 길, 반짝이는 별', [Color(0xFF1B2140), Color(0xFF2C3358), Color(0xFFFFE6A3), Color(0xFFFFD46B)]),
  MapTheme('treasure', '보물 지도', '누런 종이에 그을린 테두리, 점선 길, 나침반', [Color(0xFFEFDCAE), Color(0xFFE6CF9C), Color(0xFF4A2E17), Color(0xFFA8321E)]),
  MapTheme('sketch', '연필 스케치', '모눈 공책에 연필로 그린 흑백 지도', [Color(0xFFFCFCFA), Color(0xFFE6E8E0), Color(0xFF3B3B3B), Color(0xFF5B7FB0)]),
  MapTheme('watercolor', '수채화', '외곽선 없이 물감이 번진 지도', [Color(0xFFFBF6EC), Color(0xFFF2B48C), Color(0xFF8EC3E6), Color(0xFFA9D49A)]),
  MapTheme('sakura', '벚꽃 골목', '꽃 무늬 공원과 살랑살랑 떨어지는 꽃잎', [Color(0xFFFFF5F7), Color(0xFFF9D9E4), Color(0xFFFFC6D8), Color(0xFFC0386E)]),
  MapTheme('retro', '레트로 게임', '각진 길, 화면 격자와 주사선, 게임기 테두리', [Color(0xFFB9D77A), Color(0xFFF4D35E), Color(0xFFEE964B), Color(0xFF16210F)]),
];

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

/// 친구 방 지도에 그릴 경로 하나
class MapTrack {
  const MapTrack(this.path, this.color, {this.name = ''});
  final List<LatLng> path;
  final Color color;
  final String name;

  Map<String, Object> toJson() => {
        'coords': path.map((p) => p.toLngLat()).toList(),
        'color': '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'name': name,
      };
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

  /// 스티커 붙일 자리 표시 (null이면 지움)
  Future<void> setPick(LatLng? p) => _js('setPick', [p?.lng, p?.lat]);

  /// 지도 테마 바꾸기 (지도를 새로 그림, 표시하던 것은 그대로)
  Future<void> setTheme(String id) => _js('setTheme', [id]);

  /// 기록 스티커를 도장처럼 콩 찍기. [fly]면 화면 위에서 날아와 붙는다 (친구에게 받은 스티커)
  Future<void> stamp(String spotId, {bool fly = false}) => _js('stamp', [spotId, fly]);

  /// 친구 방: 사람마다 색이 다른 경로와 이름표
  Future<void> setTracks(List<MapTrack> tracks) => _js('setTracks', [tracks.map((t) => t.toJson()).toList()]);

  /// 점들이 한 화면에 다 들어오게 확대 (점 하나면 그 자리로 크게)
  Future<void> fitTo(List<LatLng> points, {double? maxZoom}) =>
      points.isEmpty ? Future.value() : _js('fitTo', [points.map((p) => p.toLngLat()).toList(), maxZoom]);
}

/// 만화풍 지도 (assets/map/cartoon_map.html 을 WebView로 띄운다)
class CartoonMap extends StatefulWidget {
  const CartoonMap({super.key, required this.handle, this.onReady, this.onTap, this.onEvent, this.theme});
  final MapHandle handle;

  /// 정하면 이 테마로 그린다 (테마 고르는 화면의 미리보기). 없으면 설정한 테마
  final String? theme;
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
  bool _booted = false;
  String _theme = 'pastel';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(C.cream)
      ..addJavaScriptChannel('Golmok', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _boot()))
      ..loadFlutterAsset('assets/map/cartoon_map.html');
    widget.handle._c = _c;
  }

  /// 페이지가 열리면 고른 테마로 지도를 만든다
  Future<void> _boot() async {
    _booted = true;
    try {
      await _c.runJavaScript('window.boot(${jsonEncode(_theme)})');
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(CartoonMap old) {
    super.didUpdateWidget(old);
    _follow();
  }

  /// 설정한 테마(또는 미리보기 테마)가 바뀌면 지도에도 알린다
  void _follow() {
    final want = widget.theme ?? StoreScope.of(context).mapTheme;
    if (want == _theme) return;
    _theme = want;
    if (_booted) _c.runJavaScript('window.setTheme(${jsonEncode(want)})').catchError((_) {});
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
      case 'stamped':
        HapticFeedback.mediumImpact(); // 스티커가 콩 붙을 때 폰이 톡
        widget.onEvent?.call(msg);
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
                  CircularProgressIndicator(color: C.forest),
                  const SizedBox(height: 12),
                  Text('골목 지도를 그리는 중이에요', style: jua(18, color: C.forest)),
                ]),
              ),
            ),
          ),
      ]);
}
