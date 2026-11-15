import 'package:flutter/material.dart';

/// 골목대장 색 (Expo 앱 src/lib/theme.ts, 디자인 보드 '디자인 시스템'과 같은 값)
class C {
  static const forest = Color(0xFF0E5A3C);
  static const leaf = Color(0xFF2F8A61);
  static const leafText = Color(0xFF2F7A56);
  static const cream = Color(0xFFFFF9ED);
  static const orange = Color(0xFFF39A45);
  static const orangeText = Color(0xFFA4500B);
  static const pink = Color(0xFFEE7C8B);
  static const ink = Color(0xFF24322C);
  static const muted = Color(0xFF5E6A63);
  static const line = Color(0xFFE3DCCB);
  static const lineSoft = Color(0xFFEDE6D6);
  static const white = Color(0xFFFFFFFF);
  static const mint = Color(0xFFE4F2E8);
  static const peach = Color(0xFFFDE7D3);
  static const sand = Color(0xFFF2EEE4);
  static const danger = Color(0xFFB3263A);
  static const kakao = Color(0xFFFEE500);
  static const kakaoText = Color(0xFF191600);
  static const shadow = Color(0x1F24322C); // 잉크 12%
  static const buttonShadow = Color(0x400E5A3C); // 포레스트 25%
  static const scrim = Color(0x7324322C);
}

/// 모서리 둥글기
class R {
  static const input = 14.0;
  static const card = 18.0;
  static const big = 22.0;
  static const sheet = 28.0;
}

const cardShadow = [BoxShadow(color: C.shadow, blurRadius: 12, offset: Offset(0, 4))];

/// Jua 글꼴 제목
TextStyle jua(double size, {Color color = C.forest}) =>
    TextStyle(fontFamily: 'Jua', fontSize: size, color: color, height: 1.25);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.forest,
    primary: C.forest,
    secondary: C.orange,
    surface: C.cream,
    error: C.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.cream,
      foregroundColor: C.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Jua', fontSize: 24, color: C.forest),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: C.ink, fontSize: 15),
      bodySmall: TextStyle(color: C.muted, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.input), borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.input), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.input), borderSide: const BorderSide(color: C.leaf, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.white,
      indicatorColor: C.mint,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.ink)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: C.ink),
  );
}
