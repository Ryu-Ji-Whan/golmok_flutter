import 'package:flutter/material.dart';

import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'signup.dart';

/// 이메일로 가입·로그인 (Supabase 계정)
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  bool get _valid => _email.text.contains('@') && _pw.text.length >= 6;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _email.text.trim();
    final err = _signup ? await Remote.signUp(email, _pw.text) : await Remote.signIn(email, _pw.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    // 서버에 프로필이 있으면 그 계정 기록을 이 폰으로 가져오고 바로 시작, 없으면 회원가입 이어서
    final hasProfile = await store.afterRemoteLogin();
    if (!mounted) return;
    setState(() => _busy = false);
    if (hasProfile) {
      nav.popUntil((r) => r.isFirst);
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => TermsScreen(draft: SignupDraft('email'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = Remote.available;
    return Scaffold(
      appBar: AppBar(title: Text(_signup ? '이메일로 가입' : '이메일로 로그인')),
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
        const Center(child: StickerImg('a03', size: 120)),
        const SizedBox(height: 12),
        Text(_signup ? '내 계정을 만들면\n어느 폰에서든 기록이 이어져요' : '다시 만나서 반가워요!', textAlign: TextAlign.center, style: jua(24)),
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '이메일', hintText: 'name@example.com'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pw,
          obscureText: _hide,
          autofillHints: [_signup ? AutofillHints.newPassword : AutofillHints.password],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: '비밀번호',
            helperText: _signup ? '6자 이상' : null,
            suffixIcon: IconButton(
              tooltip: _hide ? '비밀번호 보기' : '비밀번호 숨기기',
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: C.danger, fontSize: 13)),
        ],
        if (!ready) ...[
          const SizedBox(height: 12),
          const Text('이 빌드에는 서버 연결 키가 없어서 이메일 계정을 쓸 수 없어요.', style: TextStyle(color: C.danger, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          _busy ? '확인 중…' : (_signup ? '가입하기' : '로그인'),
          onPressed: ready && _valid && !_busy ? _submit : null,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => setState(() {
                _signup = !_signup;
                _error = null;
              }),
          child: Text(_signup ? '이미 계정이 있어요 · 로그인' : '처음이에요 · 이메일로 가입', style: const TextStyle(color: C.forest, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
