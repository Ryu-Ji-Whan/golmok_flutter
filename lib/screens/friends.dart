import 'package:flutter/material.dart';

import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// 친구 목록: 받은 요청 · 친구 · 보낸 요청. 친구 추가는 아이디 또는 닉네임을 정확히 입력해서
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Friend>? _list;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Remote.friends();
    if (!mounted) return;
    setState(() {
      _list = r ?? _list ?? [];
      _failed = r == null;
    });
    if (r != null) StoreScope.read(context).setFriendRequests(r.where((f) => f.state == 'received').length);
  }

  Future<void> _answer(Friend f, bool ok) async {
    final done = await Remote.answerFriend(f.id, ok);
    if (!mounted) return;
    toast(context, !done ? '처리하지 못했어요. 인터넷을 확인해 주세요' : (ok ? '${f.nickname}님과 친구가 됐어요' : '요청을 거절했어요'));
    _load();
  }

  Future<void> _remove(Friend f) async {
    final sent = f.state == 'sent';
    final ok = await confirm(
      context,
      sent ? '친구 요청을 취소할까요?' : '${f.nickname}님과 친구를 끊을까요?',
      sent ? '' : '이미 주고받은 스티커는 서로의 지도에 그대로 남아요.',
      ok: sent ? '요청 취소' : '친구 끊기',
      danger: !sent,
    );
    if (!ok) return;
    final done = await Remote.removeFriend(f.id);
    if (!mounted) return;
    if (!done) toast(context, '처리하지 못했어요. 인터넷을 확인해 주세요');
    _load();
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet))),
      builder: (_) => const _AddFriendSheet(),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!Remote.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('친구')),
        body: const _Empty('로그인하면 친구를 맺고\n스티커를 주고받을 수 있어요'),
      );
    }
    final list = _list;
    final received = list?.where((f) => f.state == 'received').toList() ?? [];
    final friends = list?.where((f) => f.isFriend).toList() ?? [];
    final sent = list?.where((f) => f.state == 'sent').toList() ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('친구'), actions: [
        TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('친구 추가', style: TextStyle(fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(foregroundColor: C.forest),
        ),
        const SizedBox(width: 8),
      ]),
      body: list == null
          ? const Center(child: CircularProgressIndicator(color: C.forest))
          : RefreshIndicator(
              color: C.forest,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                if (_failed)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('친구 목록을 불러오지 못했어요. 아래로 당겨서 다시 해 보세요', style: TextStyle(color: C.danger, fontSize: 13)),
                  ),
                if (received.isNotEmpty) ...[
                  SectionTitle('받은 친구 요청 ${received.length}'),
                  for (final f in received)
                    _Row(f, trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => _answer(f, false), child: const Text('거절', style: TextStyle(color: C.muted))),
                      FilledButton(
                        onPressed: () => _answer(f, true),
                        style: FilledButton.styleFrom(backgroundColor: C.forest, shape: const StadiumBorder()),
                        child: const Text('수락'),
                      ),
                    ])),
                ],
                SectionTitle('친구 ${friends.length}'),
                if (friends.isEmpty)
                  const _Empty('아직 친구가 없어요\n오른쪽 위 "친구 추가"에서 아이디나 닉네임으로 찾아보세요', small: true)
                else
                  for (final f in friends)
                    _Row(f, trailing: IconButton(
                      tooltip: '친구 끊기',
                      icon: const Icon(Icons.more_horiz, color: C.muted),
                      onPressed: () => _remove(f),
                    )),
                if (sent.isNotEmpty) ...[
                  SectionTitle('보낸 친구 요청 ${sent.length}'),
                  for (final f in sent)
                    _Row(f, sub: '수락을 기다리는 중', trailing: TextButton(onPressed: () => _remove(f), child: const Text('취소', style: TextStyle(color: C.muted)))),
                ],
              ]),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.f, {required this.trailing, this.sub});
  final Friend f;
  final Widget trailing;
  final String? sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CardBox(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            Avatar(f.character, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (sub != null) Text(sub!, style: const TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
            trailing,
          ]),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text, {this.small = false});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: small ? 16 : 80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          StickerImg('a02', size: small ? 64 : 100),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.muted, height: 1.5)),
        ]),
      );
}

/// 친구 추가: 아이디 또는 닉네임 입력 → 찾기 → 친구 요청
class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet();

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _q = TextEditingController();
  Friend? _found;
  String? _msg;
  bool _busy = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _q.text.trim();
    if (q.length < 2) return;
    setState(() {
      _busy = true;
      _found = null;
      _msg = null;
    });
    try {
      final f = await Remote.findFriend(q);
      setState(() => f == null ? _msg = '그런 아이디나 닉네임을 찾지 못했어요. 정확히 입력해 주세요' : _found = f);
    } catch (_) {
      setState(() => _msg = '찾지 못했어요. 인터넷을 확인해 주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    final f = _found!;
    setState(() => _busy = true);
    final r = await Remote.requestFriend(f.id);
    if (!mounted) return;
    setState(() => _busy = false);
    final text = switch (r) {
      FriendRequestResult.sent => '${f.nickname}님에게 친구 요청을 보냈어요',
      FriendRequestResult.accepted => '${f.nickname}님과 친구가 됐어요',
      FriendRequestResult.already => '이미 친구예요',
      FriendRequestResult.self => '나 자신이에요',
      FriendRequestResult.tooMany => '오늘은 친구 요청을 너무 많이 보냈어요. 내일 다시 해 주세요',
      FriendRequestResult.failed => '요청을 보내지 못했어요. 인터넷을 확인해 주세요',
    };
    final ok = r == FriendRequestResult.sent || r == FriendRequestResult.accepted;
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } else {
      setState(() => _msg = text);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('친구 추가', style: jua(24)),
          const SizedBox(height: 4),
          const Text('친구의 아이디나 닉네임을 정확히 입력해 주세요.\n카카오로 가입한 친구는 닉네임으로 찾을 수 있어요.',
              style: TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _q,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(hintText: '아이디 또는 닉네임'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _search,
                style: FilledButton.styleFrom(backgroundColor: C.forest, shape: const StadiumBorder()),
                child: const Text('찾기'),
              ),
            ),
          ]),
          if (_msg != null) ...[
            const SizedBox(height: 10),
            Text(_msg!, style: const TextStyle(fontSize: 13, color: C.danger)),
          ],
          if (_found != null) ...[
            const SizedBox(height: 14),
            CardBox(
              color: C.cream,
              shadow: false,
              child: Row(children: [
                Avatar(_found!.character, size: 52),
                const SizedBox(width: 12),
                Expanded(child: Text(_found!.nickname, style: jua(22))),
              ]),
            ),
            const SizedBox(height: 12),
            PrimaryButton('친구 요청 보내기', icon: Icons.person_add_alt_1, onPressed: _busy ? null : _request),
          ],
        ]),
      );
}
