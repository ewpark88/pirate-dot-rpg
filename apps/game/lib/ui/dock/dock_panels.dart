import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/tabs/crew_tab.dart';
import 'package:pirate_dot/ui/tabs/ship_tab.dart';
import 'package:pirate_dot/ui/tabs/summon_tab.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

/// 탭 내용 최대 폭(dp) — 태블릿에서 줄이 너무 길어지지 않게.
const _tabMaxWidth = 640.0;

/// 시트 안 패널 4개 (탭 4개 고정, 설계서 4.9). 바꿔도 각 패널의 스크롤 위치는 남는다(IndexedStack은 그대로 두고 겉만 움직인다).
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
    child: IndexedStack(
      index: widget.tab,
      children: const [
        _MaxWidth(child: VoyageTab()),
        _MaxWidth(child: ShipTab()),
        CrewTab(),
        _MaxWidth(child: SummonTab()),
      ],
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
