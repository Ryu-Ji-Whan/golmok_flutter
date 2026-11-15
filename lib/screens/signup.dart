import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// 회원가입 중 입력값 (가입 완료 때 한 번에 저장)
class SignupDraft {
  SignupDraft(this.provider);
  final String provider;
  bool terms = false, privacy = false, location = false, marketing = false;
  String nickname = '';
  String characterId = 'a02';
  String areaName = areas.first;

  bool get requiredOk => terms && privacy && location;
}

void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// 단계 화면 공통 틀
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.step, required this.title, required this.children, required this.button, this.subtitle});
  final int step;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget button;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              StepHeader(step: step),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(8, 20, 8, 16), children: [
                  Text(title, style: jua(26)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!, style: const TextStyle(fontSize: 14, color: C.muted, height: 1.5)),
                  ],
                  const SizedBox(height: 20),
                  ...children,
                ]),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: button),
            ]),
          ),
        ),
      );
}

// ── ①-B 약관 동의 (1/4) ──
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, required this.draft});
  final SignupDraft draft;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  SignupDraft get d => widget.draft;

  void _detail(String title) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: C.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet))),
        builder: (c) => SizedBox(
          height: MediaQuery.of(c).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    '[약관 본문 자리]\n\n실제 서비스에서는 법무 검토를 거친 약관 전문이 들어가요.\n\n'
                    '골목대장은 산책 경로와 위치를 지도에 기록하기 위해 위치 정보를 사용해요. '
                    '기록은 기본적으로 이 폰 안에만 저장되고, 공유를 선택한 기록만 골목 피드에 보여요.',
                    style: TextStyle(fontSize: 14, color: C.muted, height: 1.6),
                  ),
                ),
              ),
              PrimaryButton('확인', onPressed: () => Navigator.pop(c)),
            ]),
          ),
        ),
      );

  Widget _row(String label, bool value, ValueChanged<bool> onChanged, {bool required = true}) => Row(children: [
        Checkbox(value: value, onChanged: (v) => setState(() => onChanged(v ?? false)), activeColor: C.forest),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => onChanged(!value)),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: required ? '[필수] ' : '[선택] ', style: TextStyle(color: required ? C.forest : C.muted, fontWeight: FontWeight.w700)),
              TextSpan(text: label),
            ]), style: const TextStyle(fontSize: 14)),
          ),
        ),
        TextButton(onPressed: () => _detail(label), child: const Text('보기', style: TextStyle(color: C.muted, fontSize: 13))),
      ]);

  @override
  Widget build(BuildContext context) {
    final all = d.requiredOk && d.marketing;
    return _StepScaffold(
      step: 1,
      title: '골목대장 이용을 위해\n약관에 동의해 주세요',
      button: PrimaryButton('다음', onPressed: d.requiredOk
          ? () => Navigator.of(context).push(MaterialPageRoute(
                settings: const RouteSettings(name: NicknameScreen.routeName),
                builder: (_) => NicknameScreen(draft: d),
              ))
          : null),
      children: [
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            Checkbox(
              value: all,
              activeColor: C.forest,
              onChanged: (v) => setState(() {
                final on = v ?? false;
                d.terms = on;
                d.privacy = on;
                d.location = on;
                d.marketing = on;
              }),
            ),
            const Text('모두 동의할게요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        _row('이용약관', d.terms, (v) => d.terms = v),
        _row('개인정보 수집·이용', d.privacy, (v) => d.privacy = v),
        _row('위치기반서비스 이용약관', d.location, (v) => d.location = v),
        _row('이벤트·혜택 알림 받기', d.marketing, (v) => d.marketing = v, required: false),
      ],
    );
  }
}

// ── ①-D 닉네임 (2/4) ──
class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key, required this.draft});
  static const routeName = 'signup-nickname';
  final SignupDraft draft;

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  late final _ctrl = TextEditingController(text: widget.draft.nickname);
  static final _allowed = RegExp(r'^[가-힣a-zA-Z0-9]+$');
  String? _serverTaken; // 서버에서 이미 쓰는 것으로 확인된 닉네임
  bool _checking = false;

  Future<void> _next() async {
    final t = _ctrl.text.trim();
    if (Remote.signedIn) {
      setState(() => _checking = true);
      final taken = await Remote.nicknameTaken(t);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _serverTaken = taken ? t : null;
      });
      if (taken) return;
    }
    widget.draft.nickname = t;
    _push(context, CharacterScreen(draft: widget.draft));
  }

  String? get _error {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return null;
    if (t == _serverTaken) return '이미 쓰고 있는 닉네임이에요';
    if (t.length < 2 || t.length > 10) return '2~10자로 지어 주세요';
    if (!_allowed.hasMatch(t)) return '한글, 영문, 숫자만 쓸 수 있어요';
    if (takenNicknames.contains(t)) return '이미 쓰고 있는 닉네임이에요';
    return null;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _ctrl.text.trim();
    final ok = t.isNotEmpty && _error == null;
    return _StepScaffold(
      step: 2,
      title: '골목에서 불릴\n닉네임을 지어 주세요',
      subtitle: '피드와 리더보드에 보이는 이름이에요',
      button: PrimaryButton(_checking ? '확인 중…' : '다음', onPressed: ok && !_checking ? _next : null),
      children: [
        TextField(
          controller: _ctrl,
          maxLength: 10,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: '예: 골목냥이', errorText: _error, counterText: '${t.length}/10'),
        ),
        if (ok)
          const Row(children: [
            Icon(Icons.check_circle, size: 16, color: C.leaf),
            SizedBox(width: 4),
            Text('멋진 이름이에요!', style: TextStyle(fontSize: 13, color: C.leafText)),
          ]),
      ],
    );
  }
}

// ── ①-E 대표 캐릭터 (3/4) ──
class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key, required this.draft});
  final SignupDraft draft;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final sel = characters.firstWhere((c) => c.id == d.characterId, orElse: () => characters.first);
    return _StepScaffold(
      step: 3,
      title: '함께 걸을\n대표 캐릭터를 골라요',
      button: PrimaryButton('다음', onPressed: () => _push(context, LocationScreen(draft: d))),
      children: [
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(color: C.peach, shape: BoxShape.circle, border: Border.all(color: C.orange, width: 3)),
              alignment: Alignment.center,
              child: StickerImg(sel.id, size: 88),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('미리보기', style: TextStyle(fontSize: 12, color: C.muted)),
                Text(sel.name, style: jua(22)),
                const Text('프로필·리더보드·피드에\n이 캐릭터가 보여요', style: TextStyle(fontSize: 12, color: C.muted, height: 1.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: [
            for (final c in characters)
              Material(
                color: c.id == d.characterId ? C.peach : C.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(R.card),
                  side: BorderSide(color: c.id == d.characterId ? C.orange : C.line, width: c.id == d.characterId ? 2 : 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(R.card),
                  onTap: () => setState(() => d.characterId = c.id),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    StickerImg(c.id, size: 64),
                    const SizedBox(height: 4),
                    Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('나중에 프로필에서 언제든 바꿀 수 있어요.', style: TextStyle(fontSize: 12, color: C.muted)),
      ],
    );
  }
}

// ── ①-F 위치 권한 안내 (4/4) ──
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key, required this.draft});
  final SignupDraft draft;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    final r = await StoreScope.read(context).locate();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != LocateResult.ok) {
      toast(context, r == LocateResult.serviceOff ? '폰의 위치 서비스를 켜 주세요' : '위치 권한 없이도 둘러볼 수 있어요. 설정에서 언제든 켤 수 있어요');
    }
    _push(context, AreaScreen(draft: widget.draft));
  }

  @override
  Widget build(BuildContext context) => _StepScaffold(
        step: 4,
        title: '걸은 골목을 밝히려면\n위치가 필요해요',
        button: Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton(_busy ? '위치 확인 중…' : '위치 허용하기', icon: Icons.my_location, onPressed: _busy ? null : _allow),
          TextButton(
            onPressed: () => _push(context, AreaScreen(draft: widget.draft)),
            child: const Text('나중에 할게요', style: TextStyle(color: C.muted)),
          ),
        ]),
        children: const [
          Center(child: StickerImg('c04', size: 150)),
          SizedBox(height: 20),
          _Reason(Icons.route, '산책 경로 그리기', '걸은 길을 지도 위에 선으로 남겨요'),
          _Reason(Icons.cloud_outlined, '안개 걷기', '지나간 골목의 안개가 걷혀요'),
          _Reason(Icons.lock_outline, '내 폰에만 저장', '기록은 공유를 고른 것만 이웃에게 보여요'),
        ],
      );
}

class _Reason extends StatelessWidget {
  const _Reason(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: C.mint, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: C.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(body, style: const TextStyle(fontSize: 13, color: C.muted)),
            ]),
          ),
        ]),
      );
}

// ── ①-G 내 동네 설정 (4/4) ──
class AreaScreen extends StatefulWidget {
  const AreaScreen({super.key, required this.draft});
  final SignupDraft draft;

  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final list = areas.where((a) => a.contains(_q.trim())).toList();
    return _StepScaffold(
      step: 4,
      title: '내 동네를 골라 주세요',
      subtitle: '동네 리더보드와 골목 피드가 이 동네 기준으로 보여요',
      button: PrimaryButton('다음', onPressed: () => _push(context, DoneScreen(draft: d))),
      children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(hintText: '동 이름으로 찾기 (예: 행궁동)', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 12),
        for (final a in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CardBox(
              shadow: false,
              color: a == d.areaName ? C.mint : C.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => setState(() => d.areaName = a),
              child: Row(children: [
                Icon(Icons.place_outlined, color: a == d.areaName ? C.forest : C.muted),
                const SizedBox(width: 10),
                Expanded(child: Text(a, style: const TextStyle(fontSize: 14))),
                if (a == d.areaName) const Icon(Icons.check_circle, color: C.forest),
              ]),
            ),
          ),
        if (list.isEmpty) const Text('찾는 동네가 없어요. 데모에서는 목록 안에서 골라 주세요.', style: TextStyle(fontSize: 13, color: C.muted)),
      ],
    );
  }
}

// ── ①-H 가입 완료 ──
class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.draft});
  final SignupDraft draft;

  Future<void> _start(BuildContext context) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final err = await StoreScope.read(context).signup(
      Profile(
        nickname: draft.nickname.isEmpty ? '골목냥이' : draft.nickname,
        characterId: draft.characterId,
        areaName: draft.areaName,
        provider: draft.provider,
        marketing: draft.marketing,
        joinedAt: DateTime.now(),
      ),
      welcomeStickers,
    );
    if (err != null) {
      // 서버에서 닉네임이 겹친 경우: 닉네임 단계로 돌아간다
      messenger.showSnackBar(SnackBar(content: Text('$err. 다른 닉네임을 골라 주세요')));
      nav.popUntil((r) => r.settings.name == NicknameScreen.routeName || r.isFirst);
      return;
    }
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final name = draft.nickname.isEmpty ? '골목냥이' : draft.nickname;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(color: C.peach, shape: BoxShape.circle, border: Border.all(color: C.white, width: 4), boxShadow: cardShadow),
              alignment: Alignment.center,
              child: StickerImg(draft.characterId, size: 112),
            ),
            const SizedBox(height: 14),
            Text('$name님, 환영해요!', textAlign: TextAlign.center, style: jua(28)),
            const SizedBox(height: 8),
            const Text('골목대장이 될 준비 끝!\n첫 산책에서 골목을 밝혀 보세요',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: C.muted, height: 1.5)),
            const SizedBox(height: 20),
            CardBox(
              child: Column(children: [
                Row(children: [
                  const Expanded(child: Text('환영 스티커 팩이 도착했어요', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                  Pill('보관함 +${welcomeStickers.length}'),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  for (final id in welcomeStickers)
                    Expanded(
                      child: Container(
                        height: 72,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: StickerImg(id, size: 52),
                      ),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Text('내 동네 · ${draft.areaName}', style: const TextStyle(fontSize: 13, color: C.muted)),
            const Spacer(),
            PrimaryButton('첫 산책 시작하기', onPressed: () => _start(context)),
          ]),
        ),
      ),
    );
  }
}
