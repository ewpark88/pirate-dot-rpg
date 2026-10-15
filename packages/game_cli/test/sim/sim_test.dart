import 'package:game_cli/src/sim/sim_cards.dart';
import 'package:game_cli/src/sim/sim_patch.dart';
import 'package:game_cli/src/sim/sim_player.dart';
import 'package:game_cli/src/sim/sim_report.dart';
import 'package:game_cli/src/sim/sim_upgrades.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  final t = GameTables.load();

  test('가장 싼 강화: 처음엔 대포·선체(10골드), 최대 레벨 부위는 뺀다', () {
    final first = cheapestUpgrade(t, const {})!;
    expect(first.cost.closeTo(BigNum.from(10)), isTrue);
    final sail = t.shipParts.byId('sail');
    final maxed = {for (final p in t.shipParts.parts) p.id: p.id == 'sail' ? sail.maxLevel! : 1000};
    expect(cheapestUpgrade(t, maxed)!.part, isNot('sail'));
  });

  test('골드로 살 수 있는 강화 횟수', () {
    expect(upgradesAffordable(t, const {}, BigNum.from(9)), 0);
    expect(upgradesAffordable(t, const {}, BigNum.from(20)), 2); // 대포 10 + 선체 10
  });

  test('회차별 보스 카드: 시작 카드·새 보스·반복 보스를 나누고 등급은 기댓값', () {
    final b = t.growth.bossCards;
    final run = RunCards()
      ..bossCleared(t, stage: b.starterFirstStage, bestBefore: 1, rebirths: 0)
      ..bossCleared(t, stage: 1, bestBefore: 1, rebirths: 0)
      ..bossCleared(t, stage: 2, bestBefore: 50, rebirths: 1)
      ..bossCleared(t, stage: 50, bestBefore: 50, rebirths: 1);
    expect([run.starterCards, run.newBosses, run.repeatBosses], [1, 2, 1]);
    expect(RunCards.sum(run.repeatByRarity), closeTo(b.repeatCountAt(2), 1e-9));
    expect(RunCards.sum(run.newByRarity), closeTo(b.countAt(1) + b.countAt(50), 1e-9));
    expect(run.repeatByRarity['common'], closeTo(b.repeatCountAt(2) * t.rarities.bossDropRates['common']!, 1e-9));
  });

  test('--set: 테이블 값을 덮어쓰고, 없는 키는 실패', () {
    final p = GameTables.load(patchTables(rawTables, ['meta.rebirth.minStage=30', 'growth.expToNext.legend=26']));
    expect(p.meta.rebirth.integer('minStage'), 30);
    expect(p.growth.expToNext['legend'], 26);
    expect(() => patchTables(rawTables, ['meta.rebirth.minStag=30']), throwsArgumentError);
  });

  test('중앙값: 미도달(null)은 가장 큰 값으로', () {
    expect(median([3, null, 1]), 3);
    expect(median([null, null, 1]), isNull);
  });

  test('같은 시드면 같은 결과, 10분 안에 첫 보스 실패와 강화가 일어난다', () {
    const total = Duration(minutes: 10);
    const schedule = SimSchedule(online: total);
    final a = SimPlayer(t, seed: 3).run(total, schedule);
    final b = SimPlayer(t, seed: 3).run(total, schedule);
    expect(a.bestStage, b.bestStage);
    expect(a.upgrades, b.upgrades);
    expect(a.gold, b.gold);
    expect(a.upgrades, greaterThan(0));
    expect(a.firstBossFail, isNotNull);
  });

  test('daily 일정은 오프라인 시간을 포함해 진행하고 복귀 보상을 받는다', () {
    final r = SimPlayer(
      t,
      seed: 1,
    ).run(const Duration(hours: 9), const SimSchedule(online: Duration(minutes: 20), offline: Duration(hours: 8)));
    expect(r.played, greaterThanOrEqualTo(const Duration(hours: 9)));
  });

  test('판정: 시뮬이 목표 시간보다 짧으면 미도달을 판정하지 않는다', () {
    final c = SimCheck('k', 'l', null, 1, 3, unit: '시간', requiredWithin: const Duration(hours: 3));
    expect(c.ok(const Duration(hours: 2)), isTrue);
    expect(c.ok(const Duration(hours: 3)), isFalse);
  });
}
