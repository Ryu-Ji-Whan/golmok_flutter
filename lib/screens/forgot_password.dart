import 'package:flutter/material.dart';

import '../data/remote.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// 비밀번호 찾기: 가입한 이메일로 링크를 보내고, 링크를 누르면 웹페이지에서 새 비밀번호를 정한다.
/// (그 페이지에서 내 아이디도 알려 주므로 아이디를 잊었을 때도 쓴다)
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sending = false;
  String? _error;
  String? _sentTo;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = '이메일 주소를 다시 확인해 주세요');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await Remote.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = err;
      if (err == null) _sentTo = email;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('비밀번호 찾기')),
        body: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: _sentTo == null ? _form() : _sent()),
        ),
      );

  List<Widget> _form() => [
        const Center(child: StickerImg('a03', size: 110)),
        const SizedBox(height: 16),
        Text('가입할 때 쓴 이메일을 알려 주세요', style: jua(22)),
        const SizedBox(height: 6),
        const Text(
          '비밀번호를 새로 정하는 링크를 메일로 보내 드려요.\n아이디를 잊었을 때도 그 링크에서 확인할 수 있어요.',
          style: TextStyle(fontSize: 14, color: C.muted, height: 1.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.send,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _sending ? null : _send(),
          decoration: InputDecoration(labelText: '이메일', hintText: 'name@example.com', errorText: _error, prefixIcon: const Icon(Icons.mail_outline)),
        ),
        const SizedBox(height: 20),
        PrimaryButton(_sending ? '보내는 중…' : '링크 보내기', height: 54, onPressed: _sending || _email.text.trim().isEmpty ? null : _send),
        const SizedBox(height: 16),
        const Text('카카오로 가입했다면 비밀번호 없이 "카카오로 계속하기"로 로그인하면 돼요.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted)),
      ];

  List<Widget> _sent() => [
        const SizedBox(height: 12),
        const Center(child: StickerImg('c13', size: 120)),
        const SizedBox(height: 16),
        Center(child: Text('메일을 보냈어요!', style: jua(26))),
        const SizedBox(height: 10),
        Text(
          '$_sentTo 로 메일을 보냈어요.\n(가입한 이메일이 맞을 때만 메일이 가요)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: C.muted, height: 1.5),
        ),
        const SizedBox(height: 20),
        const CardBox(
          child: Text(
            '1. 메일함에서 "Reset Your Password" 메일을 열어요 (스팸함도 확인)\n'
            '2. 메일 안의 링크를 눌러요 (폰·컴퓨터 어디서든 돼요)\n'
            '3. 열린 페이지에서 아이디를 확인하고 새 비밀번호를 정해요\n'
            '4. 앱으로 돌아와 아이디와 새 비밀번호로 로그인!',
            style: TextStyle(fontSize: 14, height: 1.7),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton('로그인으로 돌아가기', height: 54, onPressed: () => Navigator.of(context).pop()),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _sentTo = null),
          child: const Text('메일이 안 왔어요 (다시 보내기)', style: TextStyle(color: C.muted)),
        ),
      ];
}
