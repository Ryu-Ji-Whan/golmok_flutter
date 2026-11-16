import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';
import 'login.dart';

/// ①-1 온보딩
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  static const _slides = [
    ('a00', '걸은 골목이\n지도로 남아요', '산책할수록 안개가 걷히고\n내 동네 지도가 밝아져요'),
    ('a18', '마음에 드는 곳엔\n스티커를 붙여요', '고양이 벤치, 골목 책방…\n나만의 장소를 기록해요'),
    ('a04', '이웃과 함께\n골목대장이 돼요', '골목 피드와 동네 리더보드로\n걷는 재미가 두 배'),
  ];

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _goLogin(context),
                child: const Text('건너뛰기', style: TextStyle(color: C.muted)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) {
                  final (sticker, title, body) = _slides[i];
                  return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(color: C.peach, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: StickerImg(sticker, size: 170),
                    ),
                    const SizedBox(height: 36),
                    Text(title, textAlign: TextAlign.center, style: jua(32)),
                    const SizedBox(height: 12),
                    Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: C.muted, height: 1.5)),
                  ]);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < _slides.length; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: k == _i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: k == _i ? C.forest : C.line, borderRadius: BorderRadius.circular(4)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              last ? '시작하기' : '다음',
              onPressed: () => last
                  ? _goLogin(context)
                  : _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
            ),
          ]),
        ),
      ),
    );
  }

  void _goLogin(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
}
