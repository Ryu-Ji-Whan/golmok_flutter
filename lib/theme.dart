import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 테마 하나의 색·제목 글씨체. 지도 테마(assets/map/cartoon_map.html 의 THEMES)와 같은 이름으로 짝을 이룬다.
/// 지도 테마를 바꾸면 앱 전체(바탕·버튼·카드·글자 색, 제목 글씨체)도 같이 바뀐다.
class Palette {
  const Palette({
    required this.forest,
    required this.leaf,
    required this.leafText,
    required this.cream,
    required this.orange,
    required this.orangeText,
    required this.pink,
    required this.ink,
    required this.muted,
    required this.line,
    required this.lineSoft,
    required this.white,
    required this.mint,
    required this.peach,
    required this.sand,
    this.font = 'Jua',
    this.fontWeight = FontWeight.w400,
    this.dark = false,
  });

  /// forest = 주 색(버튼·제목), white = 카드·입력창 바탕이자 주 색 위 글자, cream = 화면 바탕
  final Color forest, leaf, leafText, cream, orange, orangeText, pink, ink, muted, line, lineSoft, white, mint, peach, sand;

  /// 제목 글씨체 (Jua는 앱에 들어 있고, 나머지는 처음 쓸 때 구글 글꼴에서 받아 폰에 저장)
  final String font;
  final FontWeight fontWeight;

  /// 어두운 테마 (밤 산책): 상태 표시줄 글자를 밝게
  final bool dark;
}

const palettes = <String, Palette>{
  // 골목 파스텔 (기본) — Expo 앱 src/lib/theme.ts, 디자인 보드 '디자인 시스템'과 같은 값
  'pastel': Palette(
    forest: Color(0xFF0E5A3C), leaf: Color(0xFF2F8A61), leafText: Color(0xFF2F7A56), cream: Color(0xFFFFF9ED),
    orange: Color(0xFFF39A45), orangeText: Color(0xFFA4500B), pink: Color(0xFFEE7C8B), ink: Color(0xFF24322C),
    muted: Color(0xFF5E6A63), line: Color(0xFFE3DCCB), lineSoft: Color(0xFFEDE6D6), white: Color(0xFFFFFFFF),
    mint: Color(0xFFE4F2E8), peach: Color(0xFFFDE7D3), sand: Color(0xFFF2EEE4),
  ),
  // 밤 산책: 남색 바탕, 가로등 노랑이 주 색 (주 색 위 글자는 남색)
  'night': Palette(
    forest: Color(0xFFFFD46B), leaf: Color(0xFF8CE0FF), leafText: Color(0xFF8CE0FF), cream: Color(0xFF161B33),
    orange: Color(0xFFF39A45), orangeText: Color(0xFFFFB877), pink: Color(0xFFF28BA0), ink: Color(0xFFEEF0FF),
    muted: Color(0xFFA9B0D3), line: Color(0xFF3B4472), lineSoft: Color(0xFF2E3660), white: Color(0xFF232A4D),
    mint: Color(0xFF2F3866), peach: Color(0xFF3A3560), sand: Color(0xFF1E2442),
    font: 'Do Hyeon', dark: true,
  ),
  // 보물 지도: 양피지 바탕, 갈색 잉크
  'treasure': Palette(
    forest: Color(0xFF6B3A16), leaf: Color(0xFF8B5A2B), leafText: Color(0xFF7A4A20), cream: Color(0xFFF3E6C4),
    orange: Color(0xFFC8692A), orangeText: Color(0xFF8A3A12), pink: Color(0xFFC0564B), ink: Color(0xFF3A2412),
    muted: Color(0xFF7A6145), line: Color(0xFFD9C49A), lineSoft: Color(0xFFE6D5AE), white: Color(0xFFFBF3DC),
    mint: Color(0xFFEADCB4), peach: Color(0xFFF0D2A8), sand: Color(0xFFEBDDBB),
    font: 'Song Myung',
  ),
  // 연필 스케치: 흰 종이, 연필 회색
  'sketch': Palette(
    forest: Color(0xFF2A2A2A), leaf: Color(0xFF5B7FB0), leafText: Color(0xFF4A6A95), cream: Color(0xFFFCFCFA),
    orange: Color(0xFFF39A45), orangeText: Color(0xFF9A5A1A), pink: Color(0xFFE07C8B), ink: Color(0xFF1F1F1F),
    muted: Color(0xFF6B6B6B), line: Color(0xFFDDDDD6), lineSoft: Color(0xFFEAEAE4), white: Color(0xFFFFFFFF),
    mint: Color(0xFFEEF1F5), peach: Color(0xFFF4EDE4), sand: Color(0xFFF2F2EE),
    font: 'Gaegu', fontWeight: FontWeight.w700,
  ),
  // 수채화: 따뜻한 종이, 물감 파랑
  'watercolor': Palette(
    forest: Color(0xFF4C6B8A), leaf: Color(0xFF6FA06A), leafText: Color(0xFF4E7E4A), cream: Color(0xFFFBF6EC),
    orange: Color(0xFFEE9F6B), orangeText: Color(0xFFA55A2E), pink: Color(0xFFE9A3A8), ink: Color(0xFF3D3530),
    muted: Color(0xFF7A6E66), line: Color(0xFFE6DCCB), lineSoft: Color(0xFFEFE8DA), white: Color(0xFFFFFDF8),
    mint: Color(0xFFE5F0E0), peach: Color(0xFFF8E3D4), sand: Color(0xFFF2ECE0),
    font: 'Nanum Pen Script',
  ),
  // 벚꽃 골목: 연분홍
  'sakura': Palette(
    forest: Color(0xFFC0386E), leaf: Color(0xFFE06C98), leafText: Color(0xFFB0386A), cream: Color(0xFFFFF5F7),
    orange: Color(0xFFF39A45), orangeText: Color(0xFFA4500B), pink: Color(0xFFEE7C8B), ink: Color(0xFF5A3446),
    muted: Color(0xFF8A6A78), line: Color(0xFFF2D3DD), lineSoft: Color(0xFFF7E3EA), white: Color(0xFFFFFFFF),
    mint: Color(0xFFFDE6EE), peach: Color(0xFFFFE9DC), sand: Color(0xFFFBEEF2),
    font: 'Gamja Flower',
  ),
  // 레트로 게임: 옛날 게임기 연두
  'retro': Palette(
    forest: Color(0xFF2F5D1B), leaf: Color(0xFF3D6B22), leafText: Color(0xFF2F5D1B), cream: Color(0xFFE9F2CF),
    orange: Color(0xFFF08A4B), orangeText: Color(0xFF9A4A10), pink: Color(0xFFE06C7B), ink: Color(0xFF16210F),
    muted: Color(0xFF4F5E3E), line: Color(0xFFC5D6A0), lineSoft: Color(0xFFD6E3B6), white: Color(0xFFF7FBEA),
    mint: Color(0xFFD7EAB2), peach: Color(0xFFF8E3B8), sand: Color(0xFFE2EBC8),
    font: 'Do Hyeon',
  ),
};

/// 골목대장 색. 지금 테마의 색을 돌려준다 ([use]로 바꿈).
/// 테마마다 달라지므로 const 자리에는 쓸 수 없다.
class C {
  static Palette _p = palettes['pastel']!;
  static String _id = 'pastel';
  static Palette get palette => _p;
  static String get themeId => _id;

  /// 테마가 바뀌면 이름이 들어온다 (MaterialApp 다시 만들기용)
  static final changes = ValueNotifier<String>('pastel');

  /// 앱 전체 색·제목 글씨체를 이 테마로 바꾼다 (화면 다시 그리기는 AppStore.setMapTheme이 함)
  static void use(String id) {
    _id = palettes.containsKey(id) ? id : 'pastel';
    _p = palettes[_id]!;
    changes.value = _id;
  }

  static Color get forest => _p.forest;
  static Color get leaf => _p.leaf;
  static Color get leafText => _p.leafText;
  static Color get cream => _p.cream;
  static Color get orange => _p.orange;
  static Color get orangeText => _p.orangeText;
  static Color get pink => _p.pink;
  static Color get ink => _p.ink;
  static Color get muted => _p.muted;
  static Color get line => _p.line;
  static Color get lineSoft => _p.lineSoft;
  static Color get white => _p.white;
  static Color get mint => _p.mint;
  static Color get peach => _p.peach;
  static Color get sand => _p.sand;
  static Color get shadow => _p.dark ? const Color(0x66000000) : _p.ink.withValues(alpha: 0.12);
  static Color get buttonShadow => _p.forest.withValues(alpha: 0.25);
  static Color get scrim => const Color(0x7324322C);

  // 테마와 상관없는 색
  static const danger = Color(0xFFB3263A);
  static const kakao = Color(0xFFFEE500);
  static const kakaoText = Color(0xFF191600);
}

/// 모서리 둥글기
class R {
  static const input = 14.0;
  static const card = 18.0;
  static const big = 22.0;
  static const sheet = 28.0;
}

List<BoxShadow> get cardShadow => [BoxShadow(color: C.shadow, blurRadius: 12, offset: const Offset(0, 4))];

/// 제목 글꼴 (기본 Jua, 테마마다 다름)
TextStyle jua(double size, {Color? color}) {
  final base = TextStyle(fontSize: size, color: color ?? C.forest, height: 1.25, fontWeight: C.palette.fontWeight);
  final f = C.palette.font;
  if (f == 'Jua') return base.copyWith(fontFamily: 'Jua');
  try {
    return GoogleFonts.getFont(f, textStyle: base);
  } catch (_) {
    return base.copyWith(fontFamily: 'Jua');
  }
}

ThemeData buildTheme() {
  final p = C.palette;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.forest,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.forest,
    onPrimary: p.white,
    secondary: p.orange,
    surface: p.cream,
    onSurface: p.ink,
    error: C.danger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.cream,
    appBarTheme: AppBarTheme(
      backgroundColor: p.cream,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: jua(24),
      systemOverlayStyle: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: p.ink),
      bodyMedium: TextStyle(color: p.ink, fontSize: 15),
      bodySmall: TextStyle(color: p.muted, fontSize: 12),
      titleMedium: TextStyle(color: p.ink),
      titleSmall: TextStyle(color: p.ink),
      labelLarge: TextStyle(color: p.ink),
    ),
    iconTheme: IconThemeData(color: p.ink),
    dialogTheme: DialogThemeData(backgroundColor: p.white),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.white),
    listTileTheme: ListTileThemeData(textColor: p.ink, iconColor: p.ink),
    switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.white : null)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.white,
      hintStyle: TextStyle(color: p.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.input), borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.input), borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.input), borderSide: BorderSide(color: p.leaf, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.white,
      indicatorColor: p.mint,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.forest : p.muted)),
      labelTextStyle: WidgetStateProperty.all(TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.cream, fontSize: 14),
    ),
  );
}
