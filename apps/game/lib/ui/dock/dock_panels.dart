import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/tabs/crew_tab.dart';
import 'package:pirate_dot/ui/tabs/ship_tab.dart';
import 'package:pirate_dot/ui/tabs/summon_tab.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

/// 탭 내용 최대 폭(dp) — 태블릿에서 줄이 너무 길어지지 않게.
const _tabMaxWidth = 640.0;

/// 시트 안 패널 4개 (탭 4개 고정, 설계서 4.9). 지금 탭만 짓고, 바꿔도 각 패널의 스크롤 위치는 남는다(PageStorage).
class DockPanels extends StatefulWidget {
  const DockPanels({required this.tab, super.key});

  final int tab;

  @override
  State<DockPanels> createState() => _DockPanelsState();
}

class _DockPanelsState extends State<DockPanels> with SingleTickerProviderStateMixin {
  // 패널을 바꾸면 새 내용이 옆에서 16dp 밀려 들어온다 (스킨 r2 ④, 180ms).
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void didUpdateWidget(DockPanels old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) _slide.forward(from: 0).ignore();
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _slide,
    builder: (context, child) {
      final t = 1 - Curves.easeOutCubic.transform(_slide.value);
      return Opacity(
        opacity: 1 - 0.4 * t,
        child: Transform.translate(offset: Offset(16 * t, 0), child: child),
      );
    },
    // 지금 탭 하나만 짓는다 — 숨은 탭도 엔진 틱(50ms)마다 상태를 구독·재계산하면 전투가 버벅인다(사용자 버그 2026-10-16).
    // 스크롤 위치는 PageStorageKey로 탭마다 남는다.
    child: KeyedSubtree(
      key: PageStorageKey<int>(widget.tab),
      child: switch (widget.tab) {
        0 => const _MaxWidth(child: VoyageTab()),
        1 => const _MaxWidth(child: ShipTab()),
        2 => const CrewTab(),
        _ => const _MaxWidth(child: SummonTab()),
      },
    ),
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
