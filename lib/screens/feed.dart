import 'package:flutter/material.dart';

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

/// ④-2 골목 피드 (로그인했으면 서버의 공유 글, 아니면 이 폰에서 공유한 기록)
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
        if (_remote.isEmpty && mine.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(children: [
              const StickerImg('a02', size: 110),
              const SizedBox(height: 12),
              Text('아직 올라온 골목 이야기가 없어요', style: jua(20)),
              const SizedBox(height: 6),
              Text('산책하다 붙인 스티커 기록을\n"골목 피드에 공유하기"로 첫 글을 올려 보세요',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
            ]),
          ),
        const SizedBox(height: 8),
        Text(
          online ? '당겨서 새로고침할 수 있어요' : '로그인하면 이웃이 공유한 글도 보여요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: C.muted),
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
                  Text(meta, style: TextStyle(fontSize: 12, color: C.muted)),
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
            if (body.isNotEmpty) Text(body, style: TextStyle(fontSize: 14, color: C.muted, height: 1.5)),
            const SizedBox(height: 6),
            Row(children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: C.pink, size: 20),
                label: Text('$likes', style: TextStyle(color: C.ink)),
              ),
              Icon(Icons.chat_bubble_outline, color: C.muted, size: 18),
              const SizedBox(width: 4),
              Text('$comments', style: TextStyle(color: C.muted)),
            ]),
          ]),
        ),
      );
}
