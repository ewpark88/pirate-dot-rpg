import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 선체 강화가 바로 먹는다(S1 — 사용자가 '강화했는데 그대로'라고 느낄 버그): 체력 최대가 오르고, 늘어난 만큼 지금 체력도 더해진다.
void main() {
  final t = GameTables.load(rawTables);
  final start = DateTime.utc(2026, 11);

  test('같은 스테이지 안에서 선체를 올리면 다음 틱에 체력 최대 ↑, 지금 체력 + 증가분(비율 유지가 아님)', () {
    final e = CoreEngine(
      tables: t,
      clock: ManualClock(start),
      initial: GameState.newGame(playerId: 'h', seed: 1, now: start).copyWith(
        progress: const Progress(stage: 10, bestStage: 10, rebirths: 3), // 종 해금: 해역 무리 전부(원거리 포함 — 맞게)
        ship: const ShipState(parts: {'cannon': 5, 'hull': 3, 'sail': 0, 'crowsnest': 0, 'cargo': 0}),
      ),
    )..advance(200); // 맞아서 체력이 조금 깎인 상태
    final before = e.state.battle!;
    expect(before.shipHp < before.shipHpMax, isTrue, reason: '깎인 채로 시작');
    e
      ..enqueue(const OpSetShip({'hull': 20}))
      ..tick();
    final after = e.state.battle!;
    final grown = after.shipHpMax - before.shipHpMax;
    expect(grown.toDouble(), greaterThan(0), reason: '체력 최대가 바로 오른다');
    expect(
      after.shipHp.toDouble(),
      closeTo((before.shipHp + grown).toDouble(), before.shipHpMax.toDouble() * 0.02),
      reason: '늘어난 만큼 더한다(이번 틱 맞은 몫 오차만)',
    );
  });
}
