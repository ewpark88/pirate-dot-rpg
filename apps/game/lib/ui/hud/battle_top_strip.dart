import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/bounty/bounty_battle.dart';
import 'package:pirate_dot/ui/hud/boss_fail_notice.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/hud/chest_layer.dart';
import 'package:pirate_dot/ui/hud/fun_strips.dart';
import 'package:pirate_dot/ui/hud/stage_gauge.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 전장 위쪽 띠 (선원 줄·시트를 가리지 않게 위에, 높이는 되도록 낮게): 진행 게이지(+목표 한 줄) · 보스 약점 · 파밍 · 보스 실패 안내 · 튜토리얼 말풍선.
class BattleTopStrip extends StatelessWidget {
  const BattleTopStrip({required this.tutorial, super.key});

  final bool tutorial;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 진행 게이지 + 다음 목표 한 줄 (전투력은 상단 바 골드 옆).
      const StageGauge(),
      const BossWeakness(),
      // 현상금 전투 띠.
      const Padding(padding: EdgeInsets.only(top: 4), child: BountyStrip()),
      const Padding(padding: EdgeInsets.only(top: 4), child: FarmingPill()),
      // 돌발 이벤트·즉석 도전 띠 (왼쪽 위, 누름 통과).
      const Padding(
        padding: EdgeInsets.fromLTRB(10, 4, 10, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [SeaEventStrip(), SizedBox(height: 4), ChallengeStrip()],
          ),
        ),
      ),
      const BossFailNotice(),
      // 상자 광고 줄(상자가 떠 있고 광고가 준비됐을 때만) — 예전엔 도크 위라 선원 줄을 가렸다.
      const ChestAdStrip(),
      if (tutorial) const TutorialBubble(),
    ],
  );
}
