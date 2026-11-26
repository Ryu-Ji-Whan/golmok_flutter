import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/geo.dart';
import '../data/models.dart';
import '../data/remote.dart';
import '../data/rooms.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/cartoon_map.dart';
import '../widgets/ui.dart';
import 'friends.dart';

/// 방 사람마다 다른 경로 색 (최대 10명)
const _personColors = [
  Color(0xFFE4572E), Color(0xFF2E86DE), Color(0xFF17A589), Color(0xFF8E44AD), Color(0xFFF39C12),
  Color(0xFFD81B60), Color(0xFF16A085), Color(0xFF5D6D7E), Color(0xFF6D4C41), Color(0xFF7CB342),
];

String _roomJoinText(RoomJoin r) => switch (r) {
      RoomJoin.ok => '들어갔어요!',
      RoomJoin.already => '이미 들어가 있는 방이에요',
      RoomJoin.full => '방이 꽉 찼어요 (최대 $roomLimit명)',
      RoomJoin.noRoom => '그런 코드의 방이 없어요. 코드를 다시 확인해 주세요',
      RoomJoin.notFriend => '골목대장 친구만 초대할 수 있어요',
      RoomJoin.failed => '잠시 뒤 다시 해 주세요',
    };

/// ⑤-1 동네 탭의 "친구 방" 목록: 방 만들기, 코드로 들어가기, 초대 받은 방
class RoomsPane extends StatefulWidget {
  const RoomsPane({super.key});

  @override
  State<RoomsPane> createState() => _RoomsPaneState();
}

class _RoomsPaneState extends State<RoomsPane> {
  List<Room>? _rooms;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Rooms.mine();
    if (!mounted) return;
    setState(() {
      _failed = r == null;
      _rooms = r ?? _rooms;
    });
  }

  Future<String?> _ask(String title, String hint, {int max = 20, bool upper = false}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: max,
          textCapitalization: upper ? TextCapitalization.characters : TextCapitalization.none,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('확인')),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = await _ask('방 만들기', '방 이름 (예: 우리 동네 산책단)');
    if (name == null || name.isEmpty || !mounted) return;
    final code = await Rooms.create(name);
    if (!mounted) return;
    if (code == null) return toast(context, '방을 만들지 못했어요. 잠시 뒤 다시 해 주세요');
    await _load();
    if (!mounted) return;
    final room = _rooms?.where((r) => r.code == code).firstOrNull;
    if (room != null) _open(room);
  }

  Future<void> _joinByCode() async {
    final code = await _ask('코드로 들어가기', '친구에게 받은 6자리 코드', max: 6, upper: true);
    if (code == null || code.isEmpty || !mounted) return;
    final r = await Rooms.join(code);
    if (!mounted) return;
    toast(context, _roomJoinText(r));
    await _load();
  }

  Future<void> _answer(Room room, bool accept) async {
    final r = await Rooms.answer(room.id, accept);
    if (!mounted) return;
    if (accept) toast(context, _roomJoinText(r));
    await _load();
  }

  Future<void> _open(Room room) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(room: room)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!Remote.signedIn) {
      return _message('로그인하면 친구들과 방을 만들어\n오늘 걸은 길과 스티커를 함께 볼 수 있어요');
    }
    final rooms = _rooms;
    return RefreshIndicator(
      color: C.forest,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(children: [
            Expanded(child: PrimaryButton('방 만들기', icon: Icons.add, onPressed: _create)),
            const SizedBox(width: 10),
            Expanded(child: OutlineButton('코드로 들어가기', icon: Icons.vpn_key_outlined, onPressed: _joinByCode)),
          ]),
          const SizedBox(height: 16),
          if (rooms == null && !_failed)
            Padding(padding: const EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: C.forest)))
          else if (rooms == null)
            _message('방 목록을 불러오지 못했어요\n당겨서 다시 해 보세요')
          else if (rooms.isEmpty)
            _message('아직 들어간 방이 없어요\n방을 만들고 친구에게 코드를 보내 보세요')
          else
            for (final r in rooms) ...[r.invited ? _inviteCard(r) : _roomCard(r), const SizedBox(height: 10)],
          const SizedBox(height: 8),
          Text(
            '방 사람끼리만 서로의 오늘 걸은 길과 방에 올린 스티커가 보여요. 밤 12시가 지나면 경로는 사라지고, 방마다 내 경로를 숨길 수도 있어요. 한 방에 최대 $roomLimit명.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: C.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _roomCard(Room r) => CardBox(
        padding: const EdgeInsets.all(14),
        onTap: () => _open(r),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: C.mint, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Icon(Icons.groups_2_outlined, color: C.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${r.members}명${r.isOwner ? ' · 내가 만든 방' : ''}${r.hideRoute ? ' · 내 경로 숨김' : ''}',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
          Icon(Icons.chevron_right, color: C.muted),
        ]),
      );

  Widget _inviteCard(Room r) => CardBox(
        padding: const EdgeInsets.all(14),
        color: C.mint,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r.invitedBy.isEmpty ? '친구' : '${r.invitedBy}님'}이 방에 초대했어요', style: TextStyle(fontSize: 12, color: C.forest)),
          const SizedBox(height: 2),
          Text(r.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('들어가면 방 사람들에게 내 오늘 경로가 보여요 (방에서 숨길 수 있어요)', style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlineButton('거절', onPressed: () => _answer(r, false))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton('들어가기', onPressed: () => _answer(r, true))),
          ]),
        ]),
      );

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          const StickerImg('a04', size: 100),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: C.muted, height: 1.6)),
        ]),
      );
}

/// 방 하나: 지도에 사람마다 오늘 걸은 길(색이 다름) + 방에 올린 스티커
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.room});
  final Room room;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _map = MapHandle();
  List<RoomPerson> _people = [];
  List<RoomTrack> _tracks = [];
  List<RoomSticker> _stickers = [];
  bool _loading = true;
  bool _failed = false;
  late bool _hide = widget.room.hideRoute;
  int _view = 0; // 0 = 사람, 1 = 스티커

  Room get room => widget.room;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Future.wait([Rooms.people(room.id), Rooms.today(room.id), Rooms.stickers(room.id)]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = res.any((x) => x == null);
      _people = (res[0] as List<RoomPerson>?) ?? _people;
      _tracks = (res[1] as List<RoomTrack>?) ?? _tracks;
      _stickers = (res[2] as List<RoomSticker>?) ?? _stickers;
    });
    await _draw(fit: true);
  }

  Color _colorOf(String userId) {
    final i = _people.indexWhere((p) => p.id == userId);
    return _personColors[(i < 0 ? 0 : i) % _personColors.length];
  }

  String _nameOf(String userId) => _people.where((p) => p.id == userId).firstOrNull?.nickname ?? '';

  double _todayOf(String userId) => _tracks.where((t) => t.userId == userId).fold(0.0, (a, t) => a + t.meters);

  Future<void> _draw({bool fit = false}) async {
    if (!_map.ready) return;
    // 같은 사람의 여러 산책 중 마지막 것에만 이름표
    final lastOf = <String, RoomTrack>{for (final t in _tracks) t.userId: t};
    await _map.setTracks([
      for (final t in _tracks) MapTrack(t.path, _colorOf(t.userId), name: identical(lastOf[t.userId], t) ? _nameOf(t.userId) : ''),
    ]);
    await _map.setMarks([
      for (final s in _stickers) MapMark(id: s.id, pos: s.pos, sticker: s.stickerId, kind: 'room', label: s.title),
    ]);
    if (fit) {
      final pts = [for (final t in _tracks) ...t.path, for (final s in _stickers) s.pos];
      if (pts.isNotEmpty) await _map.fitTo(pts, maxZoom: 17);
    }
  }

  Future<void> _ready() async {
    final s = StoreScope.read(context);
    await _map.setFog(false); // 방 지도는 안개 없이
    await _map.setMe(s.center);
    await _map.goTo(s.center, zoom: 15);
    await _draw(fit: true);
  }

  Future<void> _setHide(bool v) async {
    setState(() => _hide = v);
    final ok = await Rooms.setHidden(room.id, v);
    if (!mounted) return;
    if (!ok) {
      setState(() => _hide = !v);
      return toast(context, '바꾸지 못했어요. 잠시 뒤 다시 해 주세요');
    }
    toast(context, v ? '이 방에서 내 경로를 숨겼어요' : '이 방 사람들에게 내 오늘 경로가 보여요');
    _load();
  }

  Future<void> _invite() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(room: room),
    );
    _load();
  }

  Future<void> _share() async {
    final s = StoreScope.read(context);
    final ids = {for (final x in _stickers.where((x) => x.isMine)) x.spotId};
    final mine = s.spots.where((x) => x.fromName == null).toList();
    if (mine.isEmpty) return toast(context, '아직 붙인 스티커가 없어요. 산책하다 하나 붙여 보세요');
    final picked = await showModalBottomSheet<Spot>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('방에 올릴 스티커를 골라 주세요. 그 자리의 위치·제목·메모가 방 사람들에게 보여요. (사진은 아직 안 가요)',
                  style: TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                for (final sp in mine)
                  ListTile(
                    leading: StickerImg(sp.stickerId, size: 40),
                    title: Text(sp.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(formatDate(sp.createdAt)),
                    trailing: ids.contains(sp.id) ? const Pill('올림') : null,
                    onTap: () => Navigator.pop(ctx, sp),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await Rooms.share(room.id, picked);
    if (!mounted) return;
    if (!ok) return toast(context, '올리지 못했어요. 잠시 뒤 다시 해 주세요');
    HapticFeedback.lightImpact();
    await _load();
    final mark = _stickers.where((x) => x.isMine && x.spotId == picked.id).firstOrNull;
    if (mark != null) {
      setState(() => _view = 1);
      await _map.fitTo([mark.pos], maxZoom: 18);
      await Future.delayed(const Duration(milliseconds: 900));
      await _map.stamp(mark.id);
    }
  }

  Future<void> _leave() async {
    final ok = await confirm(context, '방에서 나갈까요?', '내가 이 방에 올린 스티커도 함께 지워져요.', ok: '나가기', danger: true);
    if (!ok || !mounted) return;
    final done = await Rooms.leave(room.id);
    if (!mounted) return;
    if (!done) return toast(context, '나가지 못했어요. 잠시 뒤 다시 해 주세요');
    Navigator.pop(context);
  }

  void _openSticker(String id) {
    final s = _stickers.where((x) => x.id == id).firstOrNull;
    if (s == null) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StickerImg(s.stickerId, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title, style: jua(22)),
                  Text('${s.nickname} · ${formatDate(s.createdAt)}', style: TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
            ]),
            if (s.memo.isNotEmpty) ...[const SizedBox(height: 10), Text(s.memo, style: const TextStyle(height: 1.5))],
            const SizedBox(height: 14),
            if (s.isMine)
              OutlineButton('방에서 내리기', icon: Icons.delete_outline, onPressed: () async {
                Navigator.pop(ctx);
                if (await Rooms.unshare(s.id)) _load();
              }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(room.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(tooltip: '친구 초대', icon: Icon(Icons.person_add_alt_1_outlined, color: C.forest), onPressed: _invite),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'leave' ? _leave() : _load(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reload', child: Text('새로고침')),
                PopupMenuItem(value: 'leave', child: Text('방 나가기')),
              ],
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(R.big),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(border: Border.all(color: C.ink, width: 2), borderRadius: BorderRadius.circular(R.big)),
                child: Stack(children: [
                  Positioned.fill(child: CartoonMap(handle: _map, onReady: _ready, onTap: (_, id) => _openSticker(id))),
                  if (_loading) Positioned(top: 10, right: 10, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.forest))),
                ]),
              ),
            ),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Icon(Icons.wifi_off, size: 16, color: C.muted),
                const SizedBox(width: 6),
                Expanded(child: Text('방 소식을 다 불러오지 못했어요', style: TextStyle(fontSize: 12, color: C.muted))),
                TextButton(onPressed: _load, child: const Text('다시 시도')),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text('사람 ${_people.length}')),
                    ButtonSegment(value: 1, label: Text('스티커 ${_stickers.length}')),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => _view = v.first),
                  style: SegmentedButton.styleFrom(selectedBackgroundColor: C.mint, selectedForegroundColor: C.forest),
                ),
              ),
            ]),
          ),
          Expanded(child: RefreshIndicator(color: C.forest, onRefresh: _load, child: _view == 0 ? _peopleList() : _stickerList())),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: PrimaryButton('내 스티커 방에 올리기', icon: Icons.upload_outlined, color: C.orange, onPressed: _share),
            ),
          ),
        ]),
      );

  Widget _peopleList() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        children: [
          for (final p in _people)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () {
                  final pts = [for (final t in _tracks.where((t) => t.userId == p.id)) ...t.path];
                  if (pts.isNotEmpty) _map.fitTo(pts, maxZoom: 17.5);
                },
                child: Row(children: [
                  Container(width: 6, height: 40, decoration: BoxDecoration(color: _colorOf(p.id), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 10),
                  Avatar(p.character, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.isMe ? '${p.nickname} (나)' : p.nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(
                        p.hideRoute
                            ? '경로 숨김'
                            : _todayOf(p.id) > 0
                                ? '오늘 ${formatDistance(_todayOf(p.id))} 걸음'
                                : '오늘 아직 안 걸었어요',
                        style: TextStyle(fontSize: 12, color: C.muted),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          CardBox(
            padding: EdgeInsets.zero,
            shadow: false,
            child: SwitchListTile(
              value: _hide,
              onChanged: _setHide,
              activeTrackColor: C.leaf,
              title: const Text('이 방에서 내 경로 숨기기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text('켜면 이 방 사람들에게 내 오늘 경로가 안 보여요', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 8),
          Text('경로는 산책을 끝내야 올라가고, 밤 12시가 지나면 사라져요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted)),
        ],
      );

  Widget _stickerList() {
    if (_stickers.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text('아직 방에 올라온 스티커가 없어요\n아래 버튼으로 첫 스티커를 올려 보세요',
              textAlign: TextAlign.center, style: TextStyle(color: C.muted, height: 1.6)),
        ),
      ]);
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      itemCount: _stickers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = _stickers[i];
        return CardBox(
          padding: const EdgeInsets.all(10),
          onTap: () async {
            await _map.fitTo([s.pos], maxZoom: 18);
            await Future.delayed(const Duration(milliseconds: 900));
            await _map.stamp(s.id);
          },
          child: Row(children: [
            StickerImg(s.stickerId, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${s.nickname} · ${formatDate(s.createdAt)}', style: TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
            IconButton(
              tooltip: '자세히',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.chevron_right, color: C.muted),
              onPressed: () => _openSticker(s.id),
            ),
          ]),
        );
      },
    );
  }
}

/// 방에 친구 초대: 코드 보내기 + 골목대장 친구 바로 초대
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.room});
  final Room room;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  List<Friend>? _friends;
  final _done = <String>{};

  @override
  void initState() {
    super.initState();
    Remote.friends().then((r) {
      if (mounted) setState(() => _friends = (r ?? []).where((f) => f.isFriend).toList());
    });
  }

  Future<void> _inviteFriend(Friend f) async {
    final r = await Rooms.invite(widget.room.id, f.id);
    if (!mounted) return;
    if (r == RoomJoin.ok || r == RoomJoin.already) {
      setState(() => _done.add(f.id));
      if (r == RoomJoin.ok) toast(context, '${f.nickname}님을 초대했어요');
    } else {
      toast(context, _roomJoinText(r));
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.room.code;
    final list = _friends;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Text('초대 코드', style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text(code, style: jua(36).copyWith(letterSpacing: 6))),
            IconButton(
              tooltip: '복사',
              icon: Icon(Icons.copy, color: C.forest),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                toast(context, '코드를 복사했어요');
              },
            ),
          ]),
          OutlineButton('코드 보내기', icon: Icons.share_outlined, onPressed: () {
            SharePlus.instance.share(ShareParams(text: '골목대장 "${widget.room.name}" 방에 들어와! 동네 탭 → 친구 방 → 코드로 들어가기 → $code'));
          }),
          const SizedBox(height: 22),
          Text('골목대장 친구 바로 초대', style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 6),
          if (list == null)
            Padding(padding: const EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: C.forest)))
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                Text('아직 골목대장 친구가 없어요', style: TextStyle(color: C.muted)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
                  child: const Text('친구 추가하러 가기'),
                ),
              ]),
            )
          else
            for (final f in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(f.character, size: 40),
                title: Text(f.nickname, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: _done.contains(f.id)
                    ? const Pill('초대함')
                    : TextButton(onPressed: () => _inviteFriend(f), child: const Text('초대')),
              ),
        ]),
      ),
    );
  }
}
