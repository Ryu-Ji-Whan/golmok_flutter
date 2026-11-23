import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';

import 'feed.dart';
import 'mymap.dart';
import 'shop.dart';
import 'town.dart';
import 'walk.dart';

/// 로그인 뒤 첫 화면: 아래 탭 5개
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  Timer? _inbox;

  // 친구가 보낸 스티커·친구 요청 확인: 앱을 켤 때, 다시 열 때, 켜 둔 동안 1분마다
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(force: true));
    _inbox = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  @override
  void dispose() {
    _inbox?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(force: true);
  }

  void _check({bool force = false}) {
    if (!mounted) return;
    StoreScope.read(context).refreshInbox(force: force);
  }

  // 지도가 있는 탭은 처음 열 때 만들고 그 뒤로는 유지한다.
  final _visited = <int>{0};

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _tab, children: [
          const WalkTab(),
          _visited.contains(1) ? MyMapTab(active: _tab == 1) : const SizedBox(),
          _visited.contains(2) ? FeedTab(active: _tab == 2) : const SizedBox(),
          _visited.contains(3) ? const TownTab() : const SizedBox(),
          _visited.contains(4) ? const ShopTab() : const SizedBox(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          height: 68,
          onDestinationSelected: (i) => setState(() {
            _tab = i;
            _visited.add(i);
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.directions_walk), label: '산책'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '내 지도'),
            NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: '피드'),
            NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: '동네'),
            NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: '상점'),
          ],
        ),
      );
}
