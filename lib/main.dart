import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'screens/onboarding.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load(); // 폰 안 데이터베이스에서 기록을 불러온다
  runApp(GolmokApp(store: store));
}

class GolmokApp extends StatelessWidget {
  const GolmokApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => StoreScope(
        store: store,
        child: MaterialApp(
          title: '골목대장',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const Gate(),
        ),
      );
}

/// 첫 화면 결정: 처음이면 온보딩, 로그아웃 상태면 로그인, 아니면 산책 화면.
/// 가입·로그인·로그아웃 뒤에는 첫 화면까지 돌아오기만 하면 여기서 알맞은 화면을 보여 준다.
class Gate extends StatelessWidget {
  const Gate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    if (s.loggedIn) return const HomeShell();
    if (s.profile != null) return const LoginScreen();
    return const OnboardingScreen();
  }
}
