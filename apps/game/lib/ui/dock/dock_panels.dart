import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/tabs/crew_tab.dart';
import 'package:pirate_dot/ui/tabs/ship_tab.dart';
import 'package:pirate_dot/ui/tabs/summon_tab.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

/// 탭 내용 최대 폭(dp) — 태블릿에서 줄이 너무 길어지지 않게.
const _tabMaxWidth = 640.0;

/// 시트 안 패널 4개 (탭 4개 고정, 설계서 4.9). 바꿔도 각 패널의 스크롤 위치는 남는다.
class DockPanels extends StatelessWidget {
  const DockPanels({required this.tab, super.key});

  final int tab;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: tab,
    children: const [
      _MaxWidth(child: VoyageTab()),
      _MaxWidth(child: ShipTab()),
      CrewTab(),
      _MaxWidth(child: SummonTab()),
    ],
  );
}

class _MaxWidth extends StatelessWidget {
  const _MaxWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _tabMaxWidth),
      child: child,
    ),
  );
}
