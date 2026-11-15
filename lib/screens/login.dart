import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'signup.dart';

/// ①-2 로그인 (데모: 실제 소셜 로그인 없이 1.2초 뒤 진행)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _loading;

  static const _providers = [
    ('kakao', '카카오로 계속하기', C.kakao, C.kakaoText, false),
    ('apple', 'Apple로 계속하기', Color(0xFF000000), C.white, false),
    ('google', 'Google로 계속하기', C.white, C.ink, true),
  ];

  Future<void> _go(String provider) async {
    setState(() => _loading = provider);
    // ①-A 로그인 진행 상태
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: C.scrim,
      builder: (_) => Dialog(
        backgroundColor: C.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: C.forest),
            SizedBox(height: 14),
            Text('계정 확인 중이에요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('잠시만 기다려 주세요', style: TextStyle(fontSize: 12, color: C.muted)),
          ]),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.of(context).pop(); // 진행 창 닫기
    setState(() => _loading = null);
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
    final store = StoreScope.of(context);
    final p = store.profile;
    final returning = p != null && !p.loggedIn && !p.isGuest ? p : null;
    String? returningLabel;
    if (returning != null) {
      for (final x in _providers) {
        if (x.$1 == returning.provider) returningLabel = x.$2.replaceAll(' 계속하기', '');
      }
    }
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
            for (final (id, label, bg, fg, border) in _providers) ...[
              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading == null ? () => _go(id) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: bg,
                    foregroundColor: fg,
                    disabledBackgroundColor: bg,
                    disabledForegroundColor: fg,
                    shape: StadiumBorder(side: border ? const BorderSide(color: C.line) : BorderSide.none),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: Text(label),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextButton(
              onPressed: _loading == null ? _browse : null,
              child: const Text('로그인 없이 둘러보기', style: TextStyle(fontSize: 13, color: C.muted)),
            ),
            if (returning != null && returningLabel != null)
              Text('$returningLabel 들어오면 ${returning.nickname}님 계정으로 돌아가요',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: C.forest)),
            const SizedBox(height: 4),
            const Text('데모 버전: 실제 소셜 로그인 없이 회원가입 화면으로 넘어가요',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: C.muted)),
          ]),
        ),
      ),
    );
  }
}
