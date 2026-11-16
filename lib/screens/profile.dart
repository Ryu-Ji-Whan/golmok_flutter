import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/geo.dart';
import '../data/remote.dart';
import '../data/stickers.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/area_picker.dart';
import '../widgets/ui.dart';

/// 부록 · 프로필·설정 (로그아웃·초기화)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _rename(BuildContext context, AppStore s) async {
    final ctrl = TextEditingController(text: s.profile?.nickname ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: C.white,
        title: const Text('닉네임 바꾸기'),
        content: TextField(controller: ctrl, maxLength: 10, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('저장')),
        ],
      ),
    );
    if (name == null || name.length < 2) return;
    final err = await s.updateProfile(nickname: name);
    if (err != null && context.mounted) toast(context, err);
  }

  void _pickCharacter(BuildContext context, AppStore s) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: C.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet))),
        builder: (c) => Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (final ch in characters)
                InkWell(
                  borderRadius: BorderRadius.circular(R.card),
                  onTap: () {
                    s.updateProfile(characterId: ch.id);
                    Navigator.pop(c);
                  },
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    StickerImg(ch.id, size: 64),
                    Text(ch.name, style: const TextStyle(fontSize: 12)),
                  ]),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = s.profile;
    final guest = p?.isGuest ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        CardBox(
          child: Row(children: [
            GestureDetector(onTap: guest ? null : () => _pickCharacter(context, s), child: Avatar(p?.characterId ?? 'a00', size: 72)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p?.nickname ?? '손님', style: jua(24)),
                InkWell(
                  onTap: guest || p == null
                      ? null
                      : () async {
                          final area = await Navigator.of(context).push<String>(
                              MaterialPageRoute(builder: (_) => AreaPickerScreen(current: p.areaName)));
                          if (area != null) await s.updateProfile(areaName: area);
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text(p?.areaName ?? '동네 미설정', style: const TextStyle(fontSize: 13, color: C.muted))),
                      if (!guest) const Text('  바꾸기 ›', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.leaf)),
                    ]),
                  ),
                ),
                Text('가입 ${p == null ? '-' : formatDate(p.joinedAt)}', style: const TextStyle(fontSize: 12, color: C.muted)),
                Text(Remote.signedIn ? '${Remote.email ?? ({'kakao': '카카오 계정', 'google': 'Google 계정'}[p?.provider] ?? '내 계정')} · 서버에 저장 중' : '이 폰에만 저장 중',
                    style: TextStyle(fontSize: 12, color: Remote.signedIn ? C.leafText : C.muted)),
              ]),
            ),
            if (!guest) IconButton(tooltip: '닉네임 바꾸기', onPressed: () => _rename(context, s), icon: const Icon(Icons.edit_outlined)),
          ]),
        ),
        const SizedBox(height: 12),
        CardBox(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Stat(formatDistance(s.totalDistance), '총 걸은 거리'),
            Stat('${s.explored.length}칸', '밝힌 골목'),
            Stat('${s.spots.length}곳', '기록'),
          ]),
        ),
        SectionTitle('내 스티커 보관함 ${s.owned.length}/${stickers.length}'),
        CardBox(
          padding: const EdgeInsets.all(10),
          child: Wrap(spacing: 4, runSpacing: 4, children: [
            for (final st in stickers.values)
              Opacity(opacity: s.owned.contains(st.id) ? 1 : 0.18, child: StickerImg(st.id, size: 44)),
          ]),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(16)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('데모 버전 안내', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('산책 경로, 안개 걷기, 스티커 기록은 이 폰에 저장되고, 카카오·이메일로 로그인하면 내 계정(서버)에도 저장돼요. 스티커 팩 결제는 아직 준비 중이에요.',
                style: TextStyle(fontSize: 12, color: C.muted, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 14),
        OutlineButton(guest ? '로그인하러 가기' : '로그아웃', icon: Icons.lock_outline, onPressed: () async {
          final nav = Navigator.of(context);
          final ok = await confirm(
            context,
            guest ? '로그인 화면으로 갈까요?' : '로그아웃할까요?',
            guest ? '둘러보기를 끝내고 로그인 화면으로 가요. 기록은 이 폰에 남아요.' : '기록은 이 폰에 남아 있고, 같은 방법으로 다시 로그인하면 그대로 이어져요.',
            ok: guest ? '로그인하러 가기' : '로그아웃',
          );
          if (!ok) return;
          await s.logout();
          nav.popUntil((r) => r.isFirst);
        }),
        const SizedBox(height: 8),
        OutlineButton('데모 데이터 초기화', icon: Icons.delete_outline, color: C.danger, onPressed: () async {
          final nav = Navigator.of(context);
          final ok = await confirm(context, '데모 데이터를 모두 지울까요?', '기록, 지도, 스티커가 처음 상태로 돌아가고 회원가입부터 다시 시작해요.', ok: '초기화', danger: true);
          if (!ok) return;
          await s.reset();
          nav.popUntil((r) => r.isFirst);
        }),
        const SizedBox(height: 10),
        const Text('골목대장 Flutter 데모 v0.1.0', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: C.muted)),
      ]),
    );
  }
}
