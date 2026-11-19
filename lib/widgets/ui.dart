import 'package:flutter/material.dart';

import '../data/stickers.dart';
import '../theme.dart';

/// 주 버튼 (포레스트, 둥근 알약 모양)
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onPressed, this.icon, this.height = 56, this.color});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: enabled ? [BoxShadow(color: C.buttonShadow, blurRadius: 14, offset: Offset(0, 6))] : null,
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color ?? C.forest,
            foregroundColor: C.white,
            disabledBackgroundColor: C.line,
            disabledForegroundColor: C.muted,
            shape: const StadiumBorder(),
            textStyle: TextStyle(fontSize: height >= 54 ? 17 : 15, fontWeight: FontWeight.w700),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 6)],
            Text(label),
          ]),
        ),
      ),
    );
  }
}

/// 테두리 버튼 (흰 바탕, 포레스트 글자)
class OutlineButton extends StatelessWidget {
  const OutlineButton(this.label, {super.key, this.onPressed, this.icon, this.height = 56, this.color});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: C.white,
            foregroundColor: color ?? C.forest,
            side: BorderSide(color: C.line),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 6)],
            Text(label),
          ]),
        ),
      );
}

class StickerImg extends StatelessWidget {
  const StickerImg(this.id, {super.key, this.size = 56});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        stickerOf(id).asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: stickerOf(id).name,
      );
}

/// 캐릭터 동그라미
class Avatar extends StatelessWidget {
  const Avatar(this.id, {super.key, this.size = 48});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: C.peach, shape: BoxShape.circle, border: Border.all(color: C.white, width: 2)),
        alignment: Alignment.center,
        child: StickerImg(id, size: size * 0.82),
      );
}

/// 흰 카드
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap, this.shadow = true});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(color: color ?? C.white, borderRadius: BorderRadius.circular(R.card), boxShadow: shadow ? cardShadow : null),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(R.card), onTap: onTap, child: box),
    );
  }
}

/// 작은 알약 배지
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.bg, this.fg});
  final String label;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg ?? C.mint, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg ?? C.forest)),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// 숫자 하나 + 설명 (산책 통계 등)
class Stat extends StatelessWidget {
  const Stat(this.value, this.label, {super.key, this.light = false});
  final String value;
  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: jua(24, color: light ? C.white : C.forest)),
        Text(label, style: TextStyle(fontSize: 12, color: light ? C.mint : C.muted)),
      ]);
}

/// 회원가입 단계 머리 (뒤로 + n/4 + 진행 막대)
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, this.total = 4, this.onBack});
  final int step;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 44,
          child: Row(children: [
            IconButton(onPressed: onBack ?? () => Navigator.of(context).maybePop(), icon: const Icon(Icons.chevron_left, size: 28), tooltip: '뒤로'),
            const Spacer(),
            Text('$step / $total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
            const SizedBox(width: 12),
          ]),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: step / total, minHeight: 4, color: C.forest, backgroundColor: C.lineSoft),
        ),
      ]);
}

/// 두 버튼짜리 확인 창
Future<bool> confirm(BuildContext context, String title, String body, {String ok = '확인', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: C.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.big)),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: Text(body, style: TextStyle(fontSize: 14, color: C.muted, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('취소', style: TextStyle(color: C.muted))),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok, style: TextStyle(color: danger ? C.danger : C.forest, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
