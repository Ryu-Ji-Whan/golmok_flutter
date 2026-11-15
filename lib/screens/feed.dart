import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/geo.dart';
import '../data/models.dart';
import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'spot_detail.dart';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 7) return '${d.inDays}일 전';
  return formatDate(t);
}

/// ④-2 골목 피드 (서버의 실제 공유 글 또는 내가 공유한 기록 + 예시 이웃 글)
class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<RemoteFeedPost> _remote = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Remote.feed();
    if (mounted) setState(() => _remote = r);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = s.profile;
    final online = Remote.signedIn;
    // 로그인했으면 서버 글(내 공유 글 포함), 아니면 이 폰의 공유 기록
    final mine = online ? <Spot>[] : s.spots.where((x) => x.shared).toList();
    final area = (p?.areaName ?? '').split(' ').last;
    return Scaffold(
      appBar: AppBar(title: Text('$area 골목 피드')),
      body: RefreshIndicator(
        color: C.forest,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        for (final r in _remote)
          _Post(
            author: r.nickname,
            character: r.character,
            meta: '${r.area.split(' ').last} · ${_ago(r.createdAt)}',
            sticker: r.sticker,
            title: r.title,
            body: r.memo,
            likes: s.likedPosts.contains(r.id) ? 1 : 0,
            liked: s.likedPosts.contains(r.id),
            comments: 0,
            onLike: () => s.toggleLike(r.id),
            onTap: s.spotById(r.id) == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: r.id))),
          ),
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
        Text(
          online
              ? '위는 실제 이웃 글, 아래 3개는 예시 글이에요. 당겨서 새로고침할 수 있어요.'
              : '예시 이웃 글이에요. 이메일로 로그인하면 실제 이웃 글이 보여요.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: C.muted),
        ),
      ]),
      ),
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
