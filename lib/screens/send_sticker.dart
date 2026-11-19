import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/remote.dart';
import '../theme.dart';
import '../widgets/photo.dart';
import '../widgets/ui.dart';
import 'friends.dart';

/// 친구에게 스티커 보내기: 기록 한 곳(정확한 위치·스티커·제목·메모·사진)을 친구 한 명에게 보낸다.
/// 보내면 스티커가 슝 날아가고, 친구가 "받기"를 누르면 친구 지도의 그 자리에 콩 붙는다.
/// 걸은 경로는 보내지 않는다.
class SendStickerScreen extends StatefulWidget {
  const SendStickerScreen({super.key, required this.spot});
  final Spot spot;

  @override
  State<SendStickerScreen> createState() => _SendStickerScreenState();
}

class _SendStickerScreenState extends State<SendStickerScreen> with SingleTickerProviderStateMixin {
  List<Friend>? _friends;
  Friend? _to;
  bool _busy = false;
  bool _sent = false;
  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Remote.friends();
    if (!mounted) return;
    setState(() => _friends = (r ?? []).where((f) => f.isFriend).toList());
  }

  Future<void> _send() async {
    final to = _to;
    if (to == null || _busy) return;
    setState(() => _busy = true);
    final sp = widget.spot;
    List<int>? bytes;
    var ext = '.jpg';
    if (sp.photo != null && sp.photo!.startsWith('file:')) {
      try {
        final f = File(Photos.resolve(sp.photo!));
        if (await f.length() <= 10 * 1024 * 1024) {
          bytes = await f.readAsBytes();
          if (sp.photo!.toLowerCase().endsWith('.png')) ext = '.png';
        }
      } catch (_) {}
    }
    final err = await Remote.sendGift(toUser: to.id, spot: sp, photoBytes: bytes, photoExt: ext);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      toast(context, err);
      return;
    }
    HapticFeedback.lightImpact();
    await _fly.forward();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sp = widget.spot;
    return Scaffold(
      appBar: AppBar(title: const Text('친구에게 스티커 보내기')),
      body: Column(children: [
        // 보낼 스티커 (보내면 날아간다)
        SizedBox(
          height: 210,
          child: AnimatedBuilder(
            animation: _fly,
            builder: (_, child) {
              final t = Curves.easeInCubic.transform(_fly.value);
              final w = MediaQuery.of(context).size.width;
              return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                if (_fly.value > 0 && _fly.value < 1)
                  Positioned(
                    bottom: 30 + 40 * _fly.value,
                    child: Opacity(
                      opacity: (1 - _fly.value).clamp(0, 1),
                      child: Text('슝~', style: jua(30, color: C.orangeText)),
                    ),
                  ),
                if (!_sent)
                  Transform.translate(
                    offset: Offset(w * 0.55 * t, -320 * t - 30 * math.sin(_fly.value * math.pi)),
                    child: Transform.rotate(
                      angle: 1.6 * t,
                      child: Transform.scale(scale: 1 - 0.6 * t, child: Opacity(opacity: (1 - t * 0.9).clamp(0, 1), child: child)),
                    ),
                  )
                else
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    const StickerImg('a04', size: 110),
                    const SizedBox(height: 6),
                    Text('${_to?.nickname}님에게 보냈어요!', style: jua(24)),
                  ]),
              ]);
            },
            child: _StickerPreview(sp),
          ),
        ),
        Expanded(child: _sent ? _done() : _picker()),
      ]),
    );
  }

  Widget _done() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(children: [
          const Text('친구가 "받기"를 누르면 친구 지도의 이 자리에 스티커가 콩 붙어요.\n받은 스티커는 그때부터 친구의 것이 돼요.',
              textAlign: TextAlign.center, style: TextStyle(color: C.muted, height: 1.6)),
          const Spacer(),
          PrimaryButton('확인', onPressed: () => Navigator.pop(context)),
        ]),
      );

  Widget _picker() {
    if (!Remote.signedIn) {
      return const Center(child: Text('로그인하면 친구에게 보낼 수 있어요', style: TextStyle(color: C.muted)));
    }
    final list = _friends;
    if (list == null) return const Center(child: CircularProgressIndicator(color: C.forest));
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Text('아직 친구가 없어요.\n친구를 추가하면 스티커를 보낼 수 있어요.', textAlign: TextAlign.center, style: TextStyle(color: C.muted, height: 1.6)),
          const SizedBox(height: 16),
          OutlineButton('친구 추가하러 가기', icon: Icons.person_add_alt_1_outlined, onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendsScreen()));
            _load();
          }),
        ]),
      );
    }
    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
        child: Text('누구에게 보낼까요? 이 기록의 정확한 위치와 사진이 함께 가요. 걸은 길은 가지 않아요.',
            style: TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final f = list[i];
            final on = _to?.id == f.id;
            return InkWell(
              borderRadius: BorderRadius.circular(R.card),
              onTap: _busy ? null : () => setState(() => _to = f),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: on ? C.mint : C.white,
                  borderRadius: BorderRadius.circular(R.card),
                  border: Border.all(color: on ? C.forest : C.line, width: on ? 2 : 1),
                ),
                child: Row(children: [
                  Avatar(f.character, size: 42),
                  const SizedBox(width: 12),
                  Expanded(child: Text(f.nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                  Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? C.forest : C.line),
                ]),
              ),
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: PrimaryButton(
            _busy ? '보내는 중…' : (_to == null ? '친구를 골라 주세요' : '${_to!.nickname}님에게 보내기'),
            icon: Icons.send,
            color: C.orange,
            onPressed: _to == null || _busy ? null : _send,
          ),
        ),
      ),
    ]);
  }
}

/// 보낼 기록 미리보기 (스티커 + 사진 + 제목)
class _StickerPreview extends StatelessWidget {
  const _StickerPreview(this.sp);
  final Spot sp;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 150,
          height: 140,
          child: Stack(clipBehavior: Clip.none, children: [
            if (sp.photo != null)
              Positioned(
                left: 0,
                top: 8,
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(10), boxShadow: cardShadow),
                    child: ClipRRect(borderRadius: BorderRadius.circular(6), child: SpotPhoto(sp.photo!, width: 100, height: 100)),
                  ),
                ),
              ),
            Positioned(right: 0, bottom: 0, child: StickerImg(sp.stickerId, size: sp.photo != null ? 84 : 130)),
          ]),
        ),
        const SizedBox(height: 6),
        Text(sp.title, style: jua(22), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]);
}
