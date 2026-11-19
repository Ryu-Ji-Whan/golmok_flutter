import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/remote.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'signup.dart';

/// 회원가입: 아이디 · 비밀번호 · 이메일 → 이메일 인증 → 아이디로 로그인
/// 인증을 마치고 처음 로그인하면 닉네임·캐릭터·동네를 정하는 단계(signup.dart)로 이어진다.
/// 이 화면이 닫히면서 가입한 아이디를 돌려준다 (로그인 칸에 채우기용).
class AccountSignupScreen extends StatefulWidget {
  const AccountSignupScreen({super.key});

  @override
  State<AccountSignupScreen> createState() => _AccountSignupScreenState();
}

class _AccountSignupScreenState extends State<AccountSignupScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _email = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;
  String? _takenId; // 서버에서 이미 쓰는 것으로 확인된 아이디
  String? _sentTo; // 인증 메일을 보낸 주소 (보내면 안내 화면으로 바뀐다)

  @override
  void dispose() {
    for (final c in [_id, _pw, _pw2, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  String get id => _id.text.trim().toLowerCase();

  String? get _idError {
    if (id.isEmpty) return null;
    if (!Remote.usernamePattern.hasMatch(id)) return '영어 소문자·숫자·밑줄(_)로 4~20자';
    if (id == _takenId) return '이미 쓰고 있는 아이디예요';
    return null;
  }

  String? get _pwError => _pw.text.isNotEmpty && _pw.text.length < 6 ? '6자 이상으로 해 주세요' : null;
  String? get _pw2Error => _pw2.text.isNotEmpty && _pw2.text != _pw.text ? '비밀번호가 서로 달라요' : null;
  String? get _emailError {
    final e = _email.text.trim();
    if (e.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e) ? null : '이메일 주소를 확인해 주세요';
  }

  bool get _valid =>
      Remote.usernamePattern.hasMatch(id) &&
      id != _takenId &&
      _pw.text.length >= 6 &&
      _pw2.text == _pw.text &&
      _email.text.trim().isNotEmpty &&
      _emailError == null;

  Future<void> _checkId() async {
    if (!Remote.usernamePattern.hasMatch(id)) return;
    final taken = await Remote.usernameTaken(id);
    if (mounted && taken) setState(() => _takenId = id);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    if (await Remote.usernameTaken(id)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _takenId = id;
      });
      return;
    }
    final email = _email.text.trim();
    final (result, err) = await Remote.signUp(username: id, email: email, password: _pw.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
        if (err.contains('아이디')) _takenId = id;
      });
      return;
    }
    if (result == SignUpResult.signedIn) {
      // 이메일 인증을 꺼 둔 경우: 바로 닉네임·캐릭터 단계로
      final store = StoreScope.read(context);
      final nav = Navigator.of(context);
      final hasProfile = await store.afterRemoteLogin();
      if (!mounted) return;
      if (hasProfile) {
        nav.popUntil((r) => r.isFirst);
      } else {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => TermsScreen(draft: SignupDraft('email'))));
      }
      return;
    }
    setState(() {
      _busy = false;
      _sentTo = email;
    });
  }

  Future<void> _resend() async {
    final err = await Remote.resendConfirmation(_sentTo!);
    if (mounted) toast(context, err ?? '인증 메일을 다시 보냈어요');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('회원가입')),
        body: _sentTo == null ? _form() : _sent(),
      );

  Widget _form() => ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
        Text('골목대장 계정 만들기', style: jua(26)),
        const SizedBox(height: 6),
        Text('아이디와 비밀번호로 로그인하고, 이메일은 본인 확인과 비밀번호 찾기에 써요.',
            style: TextStyle(fontSize: 14, color: C.muted, height: 1.5)),
        const SizedBox(height: 24),
        TextField(
          controller: _id,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.newUsername],
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')), LengthLimitingTextInputFormatter(20)],
          onChanged: (_) => setState(() {}),
          onEditingComplete: _checkId,
          decoration: InputDecoration(labelText: '아이디', hintText: '예: golmok_cat', errorText: _idError, helperText: '영어 소문자·숫자·밑줄(_) 4~20자'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pw,
          obscureText: _hide,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() {}),
          onTap: _checkId,
          decoration: InputDecoration(
            labelText: '비밀번호',
            helperText: '6자 이상',
            errorText: _pwError,
            suffixIcon: IconButton(
              tooltip: _hide ? '비밀번호 보기' : '비밀번호 숨기기',
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pw2,
          obscureText: _hide,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: '비밀번호 확인', errorText: _pw2Error),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: '이메일', hintText: 'name@example.com', helperText: '인증 메일을 보내 드려요', errorText: _emailError),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: C.danger, fontSize: 13)),
        ],
        if (!Remote.available) ...[
          const SizedBox(height: 14),
          const Text('이 빌드에는 서버 연결 키가 없어서 가입할 수 없어요.', style: TextStyle(color: C.danger, fontSize: 13)),
        ],
        const SizedBox(height: 28),
        PrimaryButton(_busy ? '가입하는 중…' : '가입하기', onPressed: Remote.available && _valid && !_busy ? _submit : null),
      ]);

  Widget _sent() => ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), children: [
        const Center(child: StickerImg('c13', size: 130)),
        const SizedBox(height: 16),
        Text('인증 메일을 보냈어요!', textAlign: TextAlign.center, style: jua(26)),
        const SizedBox(height: 10),
        Text('$_sentTo', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        CardBox(
          child: Text(
            '1. 메일함에서 골목대장 인증 메일을 열어요 (스팸함도 봐 주세요)\n'
            '2. 메일의 링크를 눌러 인증을 마쳐요\n'
            '3. 앱으로 돌아와 아이디 "$id"로 로그인해요',
            style: const TextStyle(fontSize: 14, height: 1.7),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton('로그인하러 가기', onPressed: () => Navigator.of(context).pop(id)),
        const SizedBox(height: 8),
        TextButton(onPressed: _resend, child: Text('메일이 안 왔어요 · 다시 보내기', style: TextStyle(color: C.forest, fontWeight: FontWeight.w700))),
      ]);
}
