import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/geo.dart';
import '../data/stickers.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/photo.dart';
import '../widgets/ui.dart';

/// 사진 위에 붙인 것 하나 (스티커 또는 날짜 도장)
/// 자리·크기는 사진 크기에 대한 비율로 저장한다 (화면 크기가 달라도, 큰 사진으로 저장해도 같은 자리)
class _Item {
  _Item({this.sticker, required this.pos, required this.scale}) : rot = 0;
  final String? sticker; // null이면 날짜 도장
  Offset pos; // 가운데 (0~1)
  double scale; // 사진 너비에 대한 너비 비율
  double rot; // 라디안

  bool get isStamp => sticker == null;
  double get aspect => isStamp ? 0.2 : 1; // 높이 / 너비
}

/// ②-3 사진 꾸미기: 스티커 붙이기 · 날짜 도장 · 갤러리 저장 · SNS 공유
/// 완료하면 꾸민 사진을 앱 폴더에 새 파일로 저장하고 그 경로('file:photos/…')를 돌려준다.
class PhotoEditScreen extends StatefulWidget {
  const PhotoEditScreen({super.key, required this.photo, this.date});
  final String photo;

  /// 날짜 도장에 찍을 날짜 (없으면 오늘)
  final DateTime? date;

  @override
  State<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<PhotoEditScreen> {
  static const maxItems = 20;
  static const _bg = Color(0xFF1F2623);
  static const _tool = Color(0xFF353D39);

  final _canvasKey = GlobalKey();
  final List<_Item> _items = [];
  _Item? _sel;
  Size? _imgSize; // 원본 사진 크기 (픽셀)
  StickerCategory? _cat;
  bool _busy = false;

  // 두 손가락으로 크기·각도를 바꿀 때 시작 값
  double _startScale = 1, _startRot = 0;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    try {
      final stored = widget.photo;
      final Uint8List bytes = stored.startsWith('assets/')
          ? (await rootBundle.load(stored)).buffer.asUint8List()
          : await File(Photos.resolve(stored)).readAsBytes();
      final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
      final d = await ui.ImageDescriptor.encoded(buf);
      final size = Size(d.width.toDouble(), d.height.toDouble());
      d.dispose();
      buf.dispose();
      if (mounted) setState(() => _imgSize = size);
    } catch (_) {
      if (mounted) setState(() => _imgSize = const Size(3, 4));
    }
  }

  // ── 붙이기·고치기 ──
  void _add(_Item it) {
    if (_items.length >= maxItems) {
      toast(context, '스티커는 사진 한 장에 $maxItems개까지 붙일 수 있어요');
      return;
    }
    // 겹치지 않게 조금씩 비켜서 붙인다
    final k = _items.length % 5;
    it.pos = Offset(0.5 + (k - 2) * 0.06, 0.45 + (k - 2) * 0.05);
    setState(() {
      _items.add(it);
      _sel = it;
    });
  }

  void _addStamp() {
    final old = _items.where((x) => x.isStamp).toList();
    if (old.isNotEmpty) {
      setState(() => _sel = old.first);
      toast(context, '날짜 도장은 한 개만 붙일 수 있어요');
      return;
    }
    if (_items.length >= maxItems) return _add(_Item(pos: Offset.zero, scale: 0.6));
    setState(() {
      final it = _Item(pos: const Offset(0.4, 0.9), scale: 0.6);
      _items.add(it);
      _sel = it;
    });
  }

  void _resize(double f) {
    final s = _sel;
    if (s == null) return;
    setState(() => s.scale = (s.scale * f).clamp(0.08, 1.2));
  }

  void _rotate() {
    final s = _sel;
    if (s == null) return;
    setState(() => s.rot += math.pi / 12);
  }

  void _toFront() {
    final s = _sel;
    if (s == null) return;
    setState(() => _items
      ..remove(s)
      ..add(s));
  }

  void _remove() {
    final s = _sel;
    if (s == null) return;
    setState(() {
      _items.remove(s);
      _sel = null;
    });
  }

  /// 손가락 자리에 있는 것 (맨 위부터)
  _Item? _hit(Offset local, Size canvas) {
    for (final it in _items.reversed) {
      final c = Offset(it.pos.dx * canvas.width, it.pos.dy * canvas.height);
      final w = it.scale * canvas.width, h = w * it.aspect;
      final d = local - c;
      // 돌아간 만큼 되돌려서 네모 안에 있는지 본다
      final x = d.dx * math.cos(-it.rot) - d.dy * math.sin(-it.rot);
      final y = d.dx * math.sin(-it.rot) + d.dy * math.cos(-it.rot);
      if (x.abs() <= w / 2 + 8 && y.abs() <= h / 2 + 8) return it;
    }
    return null;
  }

  // ── 저장·공유 ──
  /// 꾸민 사진을 PNG로 그린다 (원본 사진 크기에 가깝게)
  Future<Uint8List?> _render() async {
    setState(() => _sel = null); // 선택 테두리는 빼고
    await WidgetsBinding.instance.endOfFrame;
    final box = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return null;
    final ratio = ((_imgSize?.width ?? box.size.width) / box.size.width).clamp(1.0, 4.0);
    final img = await box.toImage(pixelRatio: ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data?.buffer.asUint8List();
  }

  Future<String?> _renderToTemp() async {
    final bytes = await _render();
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'golmok_${DateTime.now().millisecondsSinceEpoch}.png'));
    await f.writeAsBytes(bytes);
    return f.path;
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToGallery() => _run(() async {
        try {
          final path = await _renderToTemp();
          if (path == null) throw Exception('render');
          if (!await Gal.hasPermission(toAlbum: true) && !await Gal.requestPermission(toAlbum: true)) {
            if (mounted) toast(context, '사진 권한이 꺼져 있어요. 설정에서 골목대장의 사진 접근을 켜 주세요');
            return;
          }
          await Gal.putImage(path, album: '골목대장');
          if (mounted) toast(context, '갤러리의 "골목대장" 앨범에 저장했어요');
        } on GalException catch (e) {
          if (mounted) {
            toast(context, e.type == GalExceptionType.permissionDenied
                ? '사진 권한이 꺼져 있어요. 설정에서 골목대장의 사진 접근을 켜 주세요'
                : e.type == GalExceptionType.notEnoughSpace
                    ? '폰 저장 공간이 모자라요'
                    : '저장하지 못했어요. 다시 해 주세요');
          }
        } catch (_) {
          if (mounted) toast(context, '저장하지 못했어요. 다시 해 주세요');
        }
      });

  Future<void> _share() => _run(() async {
        try {
          final path = await _renderToTemp();
          if (path == null) throw Exception('render');
          await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: 'image/png')], text: '#골목대장 #골목산책'));
        } catch (_) {
          if (mounted) toast(context, '공유하지 못했어요. 다시 해 주세요');
        }
      });

  Future<void> _done() => _run(() async {
        if (_items.isEmpty) {
          Navigator.of(context).pop();
          return;
        }
        final nav = Navigator.of(context);
        try {
          final bytes = await _render();
          if (bytes == null) throw Exception('render');
          final stored = await Photos.saveBytes(bytes, ext: '.png');
          nav.pop(stored);
        } catch (_) {
          if (mounted) toast(context, '사진을 저장하지 못했어요. 다시 해 주세요');
        }
      });

  Future<bool> _confirmLeave() async {
    if (_items.isEmpty) return true;
    return confirm(context, '꾸미기를 그만할까요?', '붙인 스티커는 저장되지 않아요.', ok: '그만하기', danger: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final area = (s.currentArea ?? s.profile?.areaName ?? '').split(' ').last;
    final stampText = [if (area.isNotEmpty) area, formatDate(widget.date ?? DateTime.now())].join(' · ');
    final character = s.profile?.characterId ?? 'a00';
    final mine = s.owned.map(stickerOf).where((x) => _cat == null || x.category == _cat).toList()..sort((a, b) => a.id.compareTo(b.id));
    final cats = StickerCategory.values.where((c) => s.owned.any((id) => stickerOf(id).category == c)).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: C.white,
          centerTitle: true,
          title: Text('사진 꾸미기', style: jua(22, color: C.white)),
          leading: IconButton(
            tooltip: '닫기',
            icon: const Icon(Icons.close),
            onPressed: () async {
              final nav = Navigator.of(context);
              if (await _confirmLeave()) nav.pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : _done,
              child: Text('완료', style: jua(20, color: _busy ? C.muted : C.orange)),
            ),
          ],
        ),
        body: Column(children: [
          // 사진 + 붙인 것들
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _imgSize == null
                  ? const Center(child: CircularProgressIndicator(color: C.orange))
                  : Center(
                      child: AspectRatio(
                        aspectRatio: _imgSize!.width / _imgSize!.height,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(R.card),
                          child: LayoutBuilder(builder: (_, box) => _canvas(box.biggest, stampText, character)),
                        ),
                      ),
                    ),
            ),
          ),
          // 고치기 버튼
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _toolBtn(Icons.remove, '작게', () => _resize(1 / 1.18)),
              _toolBtn(Icons.add, '크게', () => _resize(1.18)),
              _toolBtn(Icons.rotate_right, '회전', _rotate),
              _toolBtn(Icons.layers_outlined, '맨 앞', _toFront),
              _toolBtn(Icons.delete_outline, '삭제', _remove, color: C.pink),
            ]),
          ),
          const SizedBox(height: 12),
          // 스티커 고르기 + 저장·공유
          Container(
            decoration: const BoxDecoration(color: C.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet))),
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.event_outlined, size: 18, color: C.white),
                      label: const Text('날짜 도장', style: TextStyle(color: C.white, fontWeight: FontWeight.w700)),
                      backgroundColor: C.orange,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      onPressed: _addStamp,
                    ),
                  ),
                  _catChip(null, '전체'),
                  for (final c in cats) _catChip(c, categoryLabel[c]!),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                child: GridView.count(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final st in mine)
                      Material(
                        color: C.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _add(_Item(sticker: st.id, pos: Offset.zero, scale: 0.28)),
                          child: Padding(padding: const EdgeInsets.all(6), child: StickerImg(st.id)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlineButton('갤러리에 저장', icon: Icons.download_outlined, height: 50, onPressed: _busy ? null : _saveToGallery)),
                const SizedBox(width: 10),
                Expanded(child: PrimaryButton('SNS에 공유', icon: Icons.ios_share, height: 50, onPressed: _busy ? null : _share)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _canvas(Size size, String stampText, String character) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => setState(() => _sel = _hit(d.localPosition, size)),
        onScaleStart: (d) {
          final hit = _hit(d.localFocalPoint, size);
          if (hit != null) _sel = hit;
          final s = _sel;
          if (s != null) {
            _startScale = s.scale;
            _startRot = s.rot;
          }
          setState(() {});
        },
        onScaleUpdate: (d) {
          final s = _sel;
          if (s == null) return;
          setState(() {
            s.pos = Offset(
              (s.pos.dx + d.focalPointDelta.dx / size.width).clamp(0.0, 1.0),
              (s.pos.dy + d.focalPointDelta.dy / size.height).clamp(0.0, 1.0),
            );
            if (d.pointerCount >= 2) {
              s.scale = (_startScale * d.scale).clamp(0.08, 1.2);
              s.rot = _startRot + d.rotation;
            }
          });
        },
        child: RepaintBoundary(
          key: _canvasKey,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned.fill(child: SpotPhoto(widget.photo, fit: BoxFit.cover)),
            for (final it in _items) _placed(it, size, stampText, character),
          ]),
        ),
      );

  Widget _placed(_Item it, Size size, String stampText, String character) {
    final w = it.scale * size.width, h = w * it.aspect;
    final selected = identical(it, _sel);
    return Positioned(
      left: it.pos.dx * size.width - w / 2,
      top: it.pos.dy * size.height - h / 2,
      width: w,
      height: h,
      child: Transform.rotate(
        angle: it.rot,
        child: Container(
          decoration: selected
              ? BoxDecoration(border: Border.all(color: C.white, width: 2), borderRadius: BorderRadius.circular(10))
              : null,
          child: it.isStamp
              ? FittedBox(child: _Stamp(text: stampText, character: character))
              : StickerImg(it.sticker!, size: w),
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback onTap, {Color color = C.white}) {
    final on = _sel != null && !_busy;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: on ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        style: TextButton.styleFrom(
          backgroundColor: _tool,
          foregroundColor: color,
          disabledForegroundColor: C.muted,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _catChip(StickerCategory? c, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _cat == c,
          showCheckmark: false,
          selectedColor: C.forest,
          backgroundColor: C.white,
          labelStyle: TextStyle(color: _cat == c ? C.white : C.ink, fontWeight: FontWeight.w700),
          shape: const StadiumBorder(side: BorderSide(color: C.line)),
          onSelected: (_) => setState(() => _cat = c),
        ),
      );
}

/// 날짜 도장: [캐릭터] 골목대장 행궁동 · 2026.11.10
class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, required this.character});
  final String text;
  final String character;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
        decoration: BoxDecoration(color: const Color(0xF2FFF9ED), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          StickerImg(character, size: 30),
          const SizedBox(width: 6),
          Text('골목대장', style: jua(18)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14, color: C.ink, fontWeight: FontWeight.w600)),
        ]),
      );
}
