import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/hud/boss_fail_notice.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/hud/power_badge.dart';
import 'package:pirate_dot/ui/hud/stage_gauge.dart';
import 'package:pirate_dot/ui/meta/goal_bar.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 전장 위쪽 띠 (선원 줄·시트를 가리지 않게 위에): 진행 게이지 · 다음 목표 · 보스 약점 · 전투력/파밍 · 보스 실패 안내 · 튜토리얼 말풍선.
class BattleTopStrip extends StatelessWidget {
  const BattleTopStrip({required this.tutorial, super.key});

  final bool tutorial;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const StageGauge(),
      const GoalBar(),
      const BossWeakness(),
      // 전투력(왼쪽) · 파밍 중 띠.
      const Padding(
        padding: EdgeInsets.fromLTRB(10, 4, 10, 0),
        child: Row(
          children: [
            PowerBadge(),
            SizedBox(width: 8),
            Flexible(child: FarmingPill()),
          ],
        ),
      ),
      const BossFailNotice(),
      if (tutorial) const TutorialBubble(),
    ],
  );
}
