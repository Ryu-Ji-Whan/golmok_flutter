import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../data/geo.dart';
import '../data/models.dart';
import '../data/stickers.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/photo.dart';
import '../widgets/ui.dart';
import 'photo_edit.dart';

/// ②-2 스티커 붙여 기록 (새 기록 / 고치기)
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, this.edit, this.at});
  final Spot? edit;

  /// 지도에서 고른 자리 (내가 밝힌 곳). 없으면 지금 있는 자리
  final LatLng? at;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late final _title = TextEditingController(text: widget.edit?.title ?? '');
  late final _memo = TextEditingController(text: widget.edit?.memo ?? '');
  late String _sticker = widget.edit?.stickerId ?? 'a18';
  late SpotVisibility _vis = widget.edit?.visibility ?? SpotVisibility.all;
  late String? _photo = widget.edit?.photo;
  StickerCategory? _cat;
  bool _saving = false;
  bool _saved = false;
  // 이 화면에서 새로 찍거나 고른 사진들 (저장하지 않고 나가면 지운다)
  final List<String> _picked = [];

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    if (!_saved) {
      for (final f in _picked) {
        Photos.delete(f);
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final s = StoreScope.read(context);
    final nav = Navigator.of(context);
    final title = _title.text.trim().isEmpty ? stickerOf(_sticker).name : _title.text.trim();
    final e = widget.edit;
    if (e == null) {
      await s.addSpot(stickerId: _sticker, title: title, memo: _memo.text.trim(), visibility: _vis, photo: _photo, at: widget.at);
    } else {
      await s.updateSpot(e.copyWith(
          stickerId: _sticker, title: title, memo: _memo.text.trim(), visibility: _vis, photo: _photo, clearPhoto: _photo == null));
      if (e.photo != _photo) await Photos.delete(e.photo); // 바뀐 예전 사진 파일 정리
    }
    _saved = true;
    // 쓰지 않게 된 새 사진 정리 (여러 번 바꾼 경우)
    for (final f in _picked) {
      if (f != _photo) await Photos.delete(f);
    }
    nav.pop(true);
  }

  Future<void> _take(ImageSource source) async {
    try {
      final path = await Photos.pick(source);
      if (path == null || !mounted) return;
      setState(() {
        _picked.add(path);
        _photo = path;
      });
    } on PhotoError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  // ②-3 사진 꾸미기: 꾸민 사진은 새 파일로 저장되고, 저장하지 않고 나가면 지운다
  Future<void> _decorate() async {
    final photo = _photo;
    if (photo == null) return;
    final out = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PhotoEditScreen(photo: photo, date: widget.edit?.createdAt)),
    );
    if (out == null || !mounted) return;
    setState(() {
      _picked.add(out);
      _photo = out;
    });
  }

  // ②-3a 사진 넣기: 사진 찍기 / 앨범에서 고르기
  void _pickPhoto() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: C.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet))),
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('사진 넣기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: C.forest),
                title: const Text('사진 찍기'),
                onTap: () {
                  Navigator.pop(c);
                  _take(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: C.forest),
                title: const Text('앨범에서 고르기'),
                onTap: () {
                  Navigator.pop(c);
                  _take(ImageSource.gallery);
                },
              ),
              if (_photo != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: C.danger),
                  title: const Text('사진 빼기', style: TextStyle(color: C.danger)),
                  onTap: () {
                    setState(() => _photo = null);
                    Navigator.pop(c);
                  },
                ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final mine = s.owned.map(stickerOf).where((x) => _cat == null || x.category == _cat).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit == null ? '여기 기록하기' : '기록 고치기')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        // 미리보기
        CardBox(
          child: Row(children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: C.peach, borderRadius: BorderRadius.circular(R.card)),
              alignment: Alignment.center,
              child: StickerImg(_sticker, size: 80),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(stickerOf(_sticker).name, style: jua(20)),
                const SizedBox(height: 4),
                Text(widget.edit == null ? '지금 서 있는 곳에 붙여요' : '붙인 자리는 그대로예요', style: TextStyle(fontSize: 13, color: C.muted)),
              ]),
            ),
          ]),
        ),
        const SectionTitle('스티커 고르기'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _catChip(null, '전체'),
            for (final c in StickerCategory.values) _catChip(c, categoryLabel[c]!),
          ]),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final st in mine)
              Material(
                color: st.id == _sticker ? C.peach : C.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: st.id == _sticker ? C.orange : C.lineSoft, width: st.id == _sticker ? 2 : 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _sticker = st.id),
                  child: Padding(padding: const EdgeInsets.all(6), child: StickerImg(st.id)),
                ),
              ),
          ],
        ),
        const SectionTitle('어떤 곳인가요?'),
        TextField(controller: _title, maxLength: 30, decoration: const InputDecoration(hintText: '예: 저녁마다 고양이가 모이는 벤치')),
        const SizedBox(height: 6),
        TextField(controller: _memo, maxLines: 3, maxLength: 200, decoration: const InputDecoration(hintText: '메모 (선택)')),
        const SectionTitle('사진'),
        if (_photo == null)
          OutlineButton('사진 넣기', icon: Icons.add_a_photo_outlined, onPressed: _pickPhoto)
        else ...[
          GestureDetector(
            onTap: _pickPhoto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(R.card),
              child: Stack(children: [
                SpotPhoto(_photo!, height: 200, width: double.infinity),
                Positioned(right: 10, bottom: 10, child: StickerImg(_sticker, size: 64)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlineButton('사진 바꾸기', icon: Icons.photo_library_outlined, height: 48, onPressed: _pickPhoto)),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton('스티커로 꾸미기', icon: Icons.auto_awesome_outlined, height: 48, onPressed: _decorate)),
          ]),
        ],
        const SectionTitle('누구에게 보일까요?'),
        SegmentedButton<SpotVisibility>(
          segments: [for (final v in SpotVisibility.values) ButtonSegment(value: v, label: Text(visibilityLabel[v]!))],
          selected: {_vis},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _vis = v.first),
          style: SegmentedButton.styleFrom(selectedBackgroundColor: C.mint, selectedForegroundColor: C.forest),
        ),
        const SizedBox(height: 28),
        PrimaryButton(_saving ? '저장 중…' : '저장하기', onPressed: _saving ? null : _save),
      ]),
    );
  }

  Widget _catChip(StickerCategory? c, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _cat == c,
          selectedColor: C.mint,
          backgroundColor: C.white,
          onSelected: (_) => setState(() => _cat = c),
        ),
      );
}
