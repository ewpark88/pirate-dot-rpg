import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:test/test.dart';

import 'family_tables.dart';

/// 자동 보스 도전(설정 autoBoss — S1 규칙 (A)): 실패 뒤 쿨다운 + '이길 만함'(DPS × 배 HP가 실패 때의 1 ÷ (1 − 남은 HP)배)이면 재도전,
/// 아니면 fallbackSec에 그냥 재도전(방치 플레이어가 멈추지 않게). 피버 중엔 쿨다운 멈춤.
void main() {
  final t = familyTables();
  final a = t.waves.raw.obj('boss').obj('autoBoss');
  final perSec = Duration.millisecondsPerSecond ~/ t.waves.tickMs;
  final cool = (a.number('cooldownSec') * perSec).round();
  final fallback = (a.number('fallbackSec') * perSec).round();

  /// 보스에게 [left] HP를 남기고 진 직후의 파밍 상태(대포 [cannon]).
  GameState failed({double left = 0.5, int cannon = 3, bool auto = true, int feverTicks = 0}) {
    final s = GameState.newGame(playerId: 't', seed: 1, now: DateTime.utc(2026, 11), crews: const ['octo']);
    return s.copyWith(
      progress: s.progress.copyWith(stage: 8, farming: true),
      settings: Settings(autoBoss: auto),
      fleet: const ['octo'],
      fleetInit: true,
      ship: s.ship.copyWith(parts: {...s.ship.parts, 'cannon': cannon}),
      battle: BattleView(
        shipHp: BigNum.one,
        shipHpMax: BigNum.one,
        feverTicksLeft: feverTicks,
        enemies: [EnemyView(id: 1, kind: 'enemy_ship', x: 0, y: 0, hpRatio: left, boss: true)],
      ),
    );
  }

  /// 틱마다 부르고 farming이 풀린 틱(못 풀리면 null). [upgradeAt] 틱에 대포를 [to]로.
  int? ticksUntilBoss(GameState s0, {int? upgradeAt, int to = 6}) {
    final f = Field(stage: 8, shipHpMax: BigNum.one, shipHp: BigNum.one);
    var s = s0;
    for (var i = 1; i <= fallback + cool; i++) {
      if (i == upgradeAt) s = s.copyWith(ship: s.ship.copyWith(parts: {...s.ship.parts, 'cannon': to}));
      s = autoBossTick(s, f, t);
      if (!s.progress.farming) return i;
    }
    return null;
  }

  test('강화가 모자라면(보스 HP 50% 남김 → 힘 ×2 필요) fallback에, 충분히 강화하면 쿨다운에 재도전', () {
    expect(ticksUntilBoss(failed()), fallback, reason: '강화 없음');
    expect(ticksUntilBoss(failed(), upgradeAt: 10, to: 4), fallback, reason: '대포 +1(×1.37)은 모자람');
    expect(ticksUntilBoss(failed(), upgradeAt: 10), cool, reason: '대포 +3(×2.56)이면 이길 만함');
  });

  test('거의 이겼던 판(남은 HP 5%)은 조금만 강화해도 쿨다운에 재도전', () {
    expect(ticksUntilBoss(failed(left: 0.05)), fallback, reason: '×1.05 필요 — 강화 0이면 아직');
    expect(ticksUntilBoss(failed(left: 0.05), upgradeAt: 10, to: 4), cool);
  });

  test('피버 중엔 쿨다운이 멈추고, 꺼져 있으면 계속 파밍', () {
    expect(ticksUntilBoss(failed(feverTicks: 1000000)), isNull);
    expect(ticksUntilBoss(failed(auto: false)), isNull);
  });
}
