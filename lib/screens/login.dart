import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState, OAuthProvider;

import '../data/models.dart';
import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'account_signup.dart';
import 'forgot_password.dart';
import 'signup.dart';

/// ①-2 로그인
/// - 카카오·이메일: Supabase 계정 (서버에 저장, 어느 폰에서든 이어짐)
/// - 구글·Apple: 아직 붙이지 않았다 (Apple은 유료 개발자 프로그램 필요)
/// - 서버 연결 키가 없는 빌드에서는 예전처럼 이 폰에만 저장하는 데모로 동작한다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  String? _loading; // 로그인 중인 방법 (kakao / google / id)
  StreamSubscription<AuthState>? _auth;
  bool _handling = false;
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _hide = true;
  String? _error;

  static const _providers = [
    ('kakao', '카카오로 계속하기', C.kakao, C.kakaoText, false, OAuthProvider.kakao),
    // 구글은 나중에 붙일 때 여기에 한 줄 추가:
    // ('google', 'Google로 계속하기', C.white, C.ink, true, OAuthProvider.google),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 브라우저에서 로그인하고 앱으로 돌아오면 signedIn이 온다
    _auth = Remote.authChanges?.listen((s) {
      if (s.event == AuthChangeEvent.signedIn && _loading != null && _loading != 'id') _afterSocial(_loading!);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 로그인 창을 닫고 그냥 돌아온 경우: 잠시 기다렸다가 버튼을 다시 누를 수 있게
    if (state == AppLifecycleState.resumed && _loading != null) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted && !_handling && !Remote.signedIn) setState(() => _loading = null);
      });
    }
  }

  Future<void> _go(String id, OAuthProvider provider) async {
    if (!Remote.available) return _demo(id);
    setState(() => _loading = id);
    final err = await Remote.signInWithProvider(provider);
    if (!mounted) return;
    if (err != null) {
      setState(() => _loading = null);
      toast(context, err);
    }
  }

  /// 소셜 로그인 성공 뒤: 서버에 내 프로필이 있으면 기록을 가져와 바로 시작, 없으면 회원가입 이어서
  Future<void> _afterSocial(String provider) async {
    if (_handling) return;
    _handling = true;
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    final hasProfile = await store.afterRemoteLogin();
    if (!mounted) return;
    setState(() => _loading = null);
    _handling = false;
    if (hasProfile) {
      nav.popUntil((r) => r.isFirst);
    } else {
      final draft = SignupDraft(provider)..nickname = _cleanName(Remote.displayName);
      nav.push(MaterialPageRoute(builder: (_) => TermsScreen(draft: draft)));
    }
  }

  /// 소셜 계정 이름을 닉네임 규칙(한글·영문·숫자, 10자)에 맞게
  String _cleanName(String? s) {
    if (s == null) return '';
    final t = s.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '');
    return t.length > 10 ? t.substring(0, 10) : t;
  }

  /// 서버 연결이 없는 빌드: 이 폰에만 저장하는 데모 로그인
  Future<void> _demo(String provider) async {
    final store = StoreScope.read(context);
    if (store.canRestore(provider)) {
      await store.restoreLogin();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TermsScreen(draft: SignupDraft(provider))));
    }
  }

  Future<void> _browse() async {
    final store = StoreScope.read(context);
    await store.signup(
      Profile(nickname: '손님', characterId: 'a00', areaName: '수원시 팔달구 행궁동', provider: 'guest', marketing: false, joinedAt: DateTime.now()),
      const [],
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// 아이디(또는 이메일) + 비밀번호 로그인
  Future<void> _idLogin() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = 'id';
      _error = null;
    });
    final err = await Remote.signIn(_id.text, _pw.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = null;
        _error = err;
      });
      return;
    }
    await _afterSocial('email');
  }

  Future<void> _openSignup() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const AccountSignupScreen()));
    if (id != null && mounted) {
      setState(() {
        _id.text = id;
        _pw.clear();
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading != null;
    final canLogin = Remote.available && _id.text.trim().isNotEmpty && _pw.text.length >= 6 && !busy;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
          Center(child: Text('골목대장', style: jua(44))),
          const SizedBox(height: 4),
          Text('내가 걸은 골목이 지도로 남아요', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: C.muted)),
          const SizedBox(height: 12),
          const Center(child: StickerImg('a04', size: 120)),
          const SizedBox(height: 20),
          AutofillGroup(
            child: Column(children: [
              TextField(
                controller: _id,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '아이디', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pw,
                obscureText: _hide,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => canLogin ? _idLogin() : null,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _hide ? '비밀번호 보기' : '비밀번호 숨기기',
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: C.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(_loading == 'id' ? '로그인 중…' : '로그인', height: 54, onPressed: canLogin ? _idLogin : null),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('처음이에요?', style: TextStyle(fontSize: 13, color: C.muted)),
            TextButton(
              onPressed: busy ? null : _openSignup,
              child: Text('회원가입', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.forest)),
            ),
            Text('·', style: TextStyle(color: C.muted)),
            TextButton(
              onPressed: busy || !Remote.available
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
              child: Text('아이디·비밀번호 찾기', style: TextStyle(fontSize: 13, color: C.muted)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Divider(color: C.line)),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('또는', style: TextStyle(fontSize: 12, color: C.muted))),
            Expanded(child: Divider(color: C.line)),
          ]),
          const SizedBox(height: 14),
          for (final (id, label, bg, fg, border, provider) in _providers) ...[
            SizedBox(
              height: 54,
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : () => _go(id, provider),
                style: FilledButton.styleFrom(
                  backgroundColor: bg,
                  foregroundColor: fg,
                  disabledBackgroundColor: bg,
                  disabledForegroundColor: fg,
                  shape: StadiumBorder(side: border ? BorderSide(color: C.line) : BorderSide.none),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: _loading == id
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg)),
                        const SizedBox(width: 10),
                        const Text('로그인 창에서 계속해 주세요'),
                      ])
                    : Text(label),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: busy ? null : _browse,
            child: Text('로그인 없이 둘러보기', style: TextStyle(fontSize: 13, color: C.muted)),
          ),
          Text(
            Remote.available ? '로그인하면 기록이 내 계정에 저장돼서 폰을 바꿔도 이어져요' : '데모 버전: 이 폰에만 저장돼요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: C.muted),
          ),
        ]),
      ),
    );
  }
}
