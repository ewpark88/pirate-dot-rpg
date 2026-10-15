import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 환생 v2 3-2절 미리보기 (수용 기준 13 — sim 오차는 game_cli sim '환생 미리보기 추정 ÷ 실제'로 잰다).
void main() {
  final t = EconomyHarness.tables;
  final h = EconomyHarness();

  GameState at(int stage) => h.newGame().copyWith(
    progress: Progress(stage: stage, bestStage: stage),
    crews: const {'octo': CrewState(level: 20), 'turtle': CrewState(level: 20)},
    fleet: const ['octo', 'turtle'],
    fleetInit: true,
  );

  test('잠겨 있으면(스테이지 < minStage) null', () {
    expect(rebirthForecast(at(t.meta.rebirth.integer('minStage') - 1), t), isNull);
  });

  test('스테이지 50, 조각 0, 상점 0 → 전투력 배수 > 1, 돌파 시간 > 0, 표시는 forecastRoundMin 단위 올림', () {
    final f = rebirthForecast(at(50), t)!;
    expect(f.targetStage, 50);
    expect(f.powerMultiplier, greaterThan(1));
    expect(f.minutesRaw, greaterThan(0));
    final step = t.meta.rebirth.integer('forecastRoundMin');
    expect(f.minutesToBeat % step, 0);
    expect(f.minutesToBeat, greaterThanOrEqualTo(f.minutesRaw));
    expect(f.minutesToBeat - f.minutesRaw, lessThan(step));
  });

  test('상점 시작 레벨은 돌파 시간을 줄인다', () {
    final base = rebirthForecast(at(60), t)!;
    final shop = rebirthForecast(at(60).copyWith(rebirthShop: const {'startParts': 10}), t)!;
    expect(shop.minutesRaw, lessThan(base.minutesRaw));
  });
}
