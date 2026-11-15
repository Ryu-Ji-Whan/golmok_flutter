import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'spot_detail.dart';

/// ④-2 골목 피드 (내가 공유한 기록 + 예시 이웃 글)
class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = s.profile;
    final mine = s.spots.where((x) => x.shared).toList();
    final area = (p?.areaName ?? '').split(' ').last;
    return Scaffold(
      appBar: AppBar(title: Text('$area 골목 피드')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        for (final sp in mine)
          _Post(
            author: p?.nickname ?? '나',
            character: p?.characterId ?? 'a00',
            meta: '$area · 내 기록',
            sticker: sp.stickerId,
            title: sp.title,
            body: sp.memo,
            likes: s.likedPosts.contains(sp.id) ? 1 : 0,
            liked: s.likedPosts.contains(sp.id),
            comments: 0,
            onLike: () => s.toggleLike(sp.id),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: sp.id))),
          ),
        for (final f in feedPosts)
          _Post(
            author: f.author,
            character: f.character,
            meta: '${f.area} · ${f.ago}',
            sticker: f.sticker,
            title: f.title,
            body: f.body,
            likes: f.likes + (s.likedPosts.contains(f.id) ? 1 : 0),
            liked: s.likedPosts.contains(f.id),
            comments: f.comments,
            onLike: () => s.toggleLike(f.id),
          ),
        const SizedBox(height: 8),
        const Text('예시 이웃 글이에요. 내 기록은 "저장된 기록 → 골목 피드에 공유하기"로 올릴 수 있어요.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted)),
      ]),
    );
  }
}

class _Post extends StatelessWidget {
  const _Post({
    required this.author,
    required this.character,
    required this.meta,
    required this.sticker,
    required this.title,
    required this.body,
    required this.likes,
    required this.liked,
    required this.comments,
    required this.onLike,
    this.onTap,
  });

  final String author, character, meta, sticker, title, body;
  final int likes, comments;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CardBox(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(character, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(author, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(meta, style: const TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(R.card)),
              alignment: Alignment.center,
              child: StickerImg(sticker, size: 120),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 14, color: C.muted, height: 1.5)),
            const SizedBox(height: 6),
            Row(children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: C.pink, size: 20),
                label: Text('$likes', style: const TextStyle(color: C.ink)),
              ),
              const Icon(Icons.chat_bubble_outline, color: C.muted, size: 18),
              const SizedBox(width: 4),
              Text('$comments', style: const TextStyle(color: C.muted)),
            ]),
          ]),
        ),
      );
}
