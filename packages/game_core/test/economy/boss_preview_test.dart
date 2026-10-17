import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// bossPreview(S4 요청 ui-boss-compare): 전투가 실제로 부르는 보스(battle_system → startBoss)와 체력·공격·시간이 같다.
void main() {
  final t = EconomyHarness.tables;

  for (final (stage, step) in [(3, 3), (3, null), (7, null), (10, null), (25, null), (50, null), (137, null)]) {
    test('스테이지 $stage${step == null ? '' : ' (튜토리얼 $step단계)'}: 전투 보스와 같은 값', () {
      final h = EconomyHarness();
      final s = h.newGame().copyWith(
        progress: Progress(stage: stage, bestStage: stage),
        tutorialStep: step,
        clearTutorial: step == null,
      );
      final f = Field(stage: stage, shipHpMax: BigNum.one, shipHp: BigNum.one)
        ..enemyHpScale = treasureHpMultiplier(s, t);
      startBoss(f, stage, h.ctx, hpScale: tutorialBossScale(s, t));
      final boss = f.foes.firstWhere((e) => e.boss);
      final p = bossPreview(s, t);
      expect(p.bossId, boss.kind);
      expect(p.maxHp.closeTo(boss.maxHp), isTrue, reason: '${p.maxHp} vs ${boss.maxHp}');
      expect(p.attack.closeTo(boss.attack), isTrue);
      expect((p.timeLimitSec, f.bossTicksLeft), (null, 0), reason: '보스 시간 제한 없음(2026-10-17)');
    });
  }

  test('튜토리얼 3단계 보스는 일부러 단단하다(tutorialFailHpMultiplier)', () {
    final h = EconomyHarness();
    final base = h.newGame().copyWith(progress: const Progress(stage: 3, bestStage: 3));
    final tut = bossPreview(base.copyWith(tutorialStep: 3), t).maxHp;
    final plain = bossPreview(base.copyWith(clearTutorial: true), t).maxHp;
    // 튜토리얼 보스는 초반 감쇠 없이 × tutorialFailHpMultiplier, 같은 스테이지 재도전은 감쇠(earlyRamp)만 — 한 번 지고 강화 뒤엔 이긴다.
    final early = earlyRamp(t.waves, 3, t.waves.earlyHpMultiplier);
    expect((tut / plain).toDouble(), closeTo(t.waves.tutorialFailHpMultiplier / early, 1e-6));
  });
}
