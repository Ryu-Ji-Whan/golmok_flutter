import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState, OAuthProvider;

import '../data/models.dart';
import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'email_auth.dart';
import 'signup.dart';

/// ①-2 로그인
/// - 이메일·카카오·구글: Supabase 계정 (서버에 저장, 어느 폰에서든 이어짐)
/// - Apple: Apple 개발자 프로그램(유료)에 가입하면 붙인다. 그 전까지는 버튼을 숨긴다.
/// - 서버 연결 키가 없는 빌드에서는 예전처럼 이 폰에만 저장하는 데모로 동작한다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  String? _loading; // 로그인 중인 방법 (kakao / google)
  StreamSubscription<AuthState>? _auth;
  bool _handling = false;

  static const _providers = [
    ('kakao', '카카오로 계속하기', C.kakao, C.kakaoText, false, OAuthProvider.kakao),
    ('google', 'Google로 계속하기', C.white, C.ink, true, OAuthProvider.google),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 브라우저에서 로그인하고 앱으로 돌아오면 signedIn이 온다
    _auth = Remote.authChanges?.listen((s) {
      if (s.event == AuthChangeEvent.signedIn && _loading != null) _afterSocial(_loading!);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final busy = _loading != null;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(children: [
            const Text('① 로그인', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.leafText)),
            const SizedBox(height: 4),
            Text('골목대장', style: jua(44)),
            const SizedBox(height: 8),
            const Text('내가 걸은 골목이 지도로 남아요\n3초 만에 시작해요',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: C.muted, height: 1.5)),
            const SizedBox(height: 24),
            const StickerImg('a04', size: 170),
            const Spacer(),
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
                    shape: StadiumBorder(side: border ? const BorderSide(color: C.line) : BorderSide.none),
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
            OutlineButton('이메일로 계속하기', icon: Icons.mail_outline, height: 54, onPressed: busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmailAuthScreen()))),
            TextButton(
              onPressed: busy ? null : _browse,
              child: const Text('로그인 없이 둘러보기', style: TextStyle(fontSize: 13, color: C.muted)),
            ),
            Text(
              Remote.available ? '로그인하면 기록이 내 계정에 저장돼서 폰을 바꿔도 이어져요' : '데모 버전: 이 폰에만 저장돼요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: C.muted),
            ),
          ]),
        ),
      ),
    );
  }
}
