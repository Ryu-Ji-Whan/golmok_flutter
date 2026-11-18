import 'package:flutter/material.dart';

import '../data/geo.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/photo.dart';
import '../widgets/ui.dart';
import 'photo_edit.dart';
import 'record.dart';

/// ③-1 저장된 기록
class SpotDetailScreen extends StatelessWidget {
  const SpotDetailScreen({super.key, required this.spotId});
  final String spotId;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final sp = s.spotById(spotId);
    if (sp == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('지워진 기록이에요')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('저장된 기록'),
        actions: [
          IconButton(
            tooltip: '고치기',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordScreen(edit: sp))),
          ),
          IconButton(
            tooltip: '지우기',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final nav = Navigator.of(context);
              if (await confirm(context, '이 기록을 지울까요?', '지운 기록은 되돌릴 수 없어요.', ok: '지우기', danger: true)) {
                await s.deleteSpot(sp.id);
                await Photos.delete(sp.photo);
                nav.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(R.big),
          child: Container(
            height: 240,
            color: C.peach,
            child: Stack(fit: StackFit.expand, children: [
              if (sp.photo != null) SpotPhoto(sp.photo!),
              Align(
                alignment: sp.photo != null ? Alignment.bottomRight : Alignment.center,
                child: Padding(padding: const EdgeInsets.all(12), child: StickerImg(sp.stickerId, size: sp.photo != null ? 88 : 150)),
              ),
            ]),
          ),
        ),
        if (sp.photo != null) ...[
          const SizedBox(height: 10),
          OutlineButton('사진 꾸미기', icon: Icons.auto_awesome_outlined, height: 48, onPressed: () async {
            final old = sp.photo;
            final out = await Navigator.of(context).push<String>(
              MaterialPageRoute(builder: (_) => PhotoEditScreen(photo: old!, date: sp.createdAt)),
            );
            if (out == null) return;
            await s.updateSpot(sp.copyWith(photo: out));
            await Photos.delete(old);
          }),
        ],
        const SizedBox(height: 16),
        Text(sp.title, style: jua(26)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(formatDate(sp.createdAt), bg: C.sand, fg: C.muted),
          Pill(visibilityLabel[sp.visibility]!),
          if (sp.shared) const Pill('피드에 공유됨', bg: C.peach, fg: C.orangeText),
        ]),
        if (sp.memo.isNotEmpty) ...[
          const SizedBox(height: 14),
          CardBox(child: Text(sp.memo, style: const TextStyle(fontSize: 15, height: 1.6))),
        ],
        const SizedBox(height: 14),
        Text('위치 ${sp.lat.toStringAsFixed(5)}, ${sp.lng.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12, color: C.muted)),
        const SizedBox(height: 24),
        if (!sp.shared)
          PrimaryButton('골목 피드에 공유하기', icon: Icons.ios_share,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShareScreen(spot: sp))))
        else
          OutlineButton('공유 그만하기', onPressed: () => s.updateSpot(sp.copyWith(shared: false))),
      ]),
    );
  }
}

/// ④-1 기록 공유하기
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.spot});
  final Spot spot;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  bool _showArea = true;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final sp = widget.spot;
    final p = s.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('기록 공유하기')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        const Text('이웃에게 이렇게 보여요', style: TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 8),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(p?.characterId ?? 'a00', size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p?.nickname ?? '손님', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(_showArea ? '${(p?.areaName ?? '').split(' ').last} · 방금' : '방금', style: const TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              StickerImg(sp.stickerId, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sp.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (sp.memo.isNotEmpty) Text(sp.memo, style: const TextStyle(fontSize: 13, color: C.muted)),
                ]),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _showArea,
          onChanged: (v) => setState(() => _showArea = v),
          activeTrackColor: C.leaf,
          title: const Text('동네 이름 함께 보여 주기'),
          subtitle: const Text('정확한 위치는 보이지 않아요'),
        ),
        const SizedBox(height: 24),
        PrimaryButton('골목 피드에 올리기', onPressed: () async {
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          await s.updateSpot(sp.copyWith(shared: true, visibility: SpotVisibility.all));
          messenger.showSnackBar(const SnackBar(content: Text('골목 피드에 올렸어요')));
          nav.pop();
        }),
      ]),
    );
  }
}
