import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/bounty/bounty_battle.dart';
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/hud/boss_fail_notice.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/hud/cargo.dart';
import 'package:pirate_dot/ui/hud/fever_slot.dart';
import 'package:pirate_dot/ui/hud/fun_strips.dart';
import 'package:pirate_dot/ui/hud/stage_gauge.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_ready.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 전장 위쪽 (선원 줄·시트를 가리지 않게, 전장 가운데 60%를 덮지 않게): 진행 게이지(+목표·파밍·피버) · 왼쪽 위 작은 알약들 · 보스 실패 안내 · 튜토리얼 말풍선.
/// 전폭 불투명 띠 금지(사용자 지시 2026-10-16) — 띠는 모두 왼쪽 위 작은 알약.
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
      // 왼쪽 위 작은 알약들 (현상금·돌발 이벤트·즉석 도전) — 옆으로 나란히, 넘치면 다음 줄. 누름 통과.
      // 현상금 전투 중에는 돌발 이벤트·도전이 멈추므로(계획 '영향') 현상금 알약만.
      const Padding(padding: EdgeInsets.fromLTRB(10, 4, 10, 0), child: _Pills()),
      // 처음 환생할 수 있게 된 순간 큰 말풍선 한 번.
      const RebirthReadyBubble(),
      const BossFailNotice(),
      if (tutorial) const TutorialBubble(),
    ],
  );
}

class _Pills extends ConsumerWidget {
  const _Pills();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bounty = ref.watch(bountyProvider.select((v) => v.active != null));
    final (fever, challenge, sea) = ref.watch(
      gameStateProvider.select(
        (s) => ((s.battle?.feverTicksLeft ?? 0) > 0, s.battle?.challenge != null, s.battle?.seaEvent != null),
      ),
    );
    final cargoFull = ref.watch(cargoLevelProvider) == 2;
    final rebirth = ref.watch(rebirthReadyProvider);
    // 우선순위: 현상금 > 도전 > 돌발 이벤트(잠깐) > 화물칸 가득 > 환생 가능(계속). 한 줄에 들어가게 최대 2개,
    // 피버 동안은(오른쪽에 원형 시간) 1개. 도전이 끝난 '성공' 알약은 도전 자리에 잠깐.
    final List<Widget> pills;
    if (bounty) {
      pills = const [BountyStrip()];
    } else {
      final ranked = <Widget>[
        if (challenge) const ChallengeStrip(),
        if (sea) const SeaEventStrip(),
        if (cargoFull) const CargoFullPill(),
        if (rebirth) const RebirthReadyPill(),
      ];
      pills = [...ranked.take(fever ? 1 : 2), if (!challenge) const ChallengeStrip()];
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 6, runSpacing: 4, children: pills),
          ),
        ),
        const FeverSlot(),
      ],
    );
  }
}
