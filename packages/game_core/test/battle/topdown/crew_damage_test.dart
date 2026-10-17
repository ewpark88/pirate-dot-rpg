import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 선원별 피해 집계 (사용자 피드백 #13·#14, 요청서 docs/contracts/requests/platform-crew-damage.md):
/// BattleView.crewDamage(스테이지) · BossCleared.crewDamage/mvp(보스전), 남은 HP로 자른 실제 피해, 선원 몫만.
void main() {
  final start = DateTime.utc(2026, 11);
  final tables = GameTables.load();

  Foe foe(int id, int hp, {bool boss = false, int? ownerId}) => Foe(
    id: id,
    kind: 'crab',
    layer: 'surface',
    x: 0,
    y: 0,
    maxHp: BigNum.from(hp),
    speed: 0,
    attack: BigNum.one,
    gold: BigNum.one,
    boss: boss,
    ownerId: ownerId,
  );

  Round round(Field f) => Round(
    f,
    SystemContext(tables: tables, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {}),
    CombatStats.of(GameState.newGame(playerId: 'c', seed: 1, now: start), tables),
  );

  test('넘친 피해는 남은 HP까지만, crewId 없는 피해(피버 오라·자폭)는 세지 않는다, 보스전은 보스·촉수만', () {
    final f = Field(stage: 5, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))..bossActive = true;
    final mob = foe(1, 100);
    final boss = foe(2, 1000, boss: true);
    final tentacle = foe(3, 50, ownerId: 2);
    f.foes.addAll([mob, boss, tentacle]);
    round(f)
      ..strike((x: 0, y: 0, hits: [(foe: mob, factor: 1.0)]), BigNum.from(500), crewId: 'octo')
      ..strike(
        (x: 0, y: 0, hits: [(foe: boss, factor: 1.0), (foe: tentacle, factor: 1.0)]),
        BigNum.from(300),
        crewId: 'pang',
      )
      ..strike((x: 0, y: 0, hits: [(foe: boss, factor: 1.0)]), BigNum.from(999)); // 선원 몫 아님
    expect(f.crewDamage, {'octo': BigNum.from(100), 'pang': BigNum.from(350)});
    expect(f.bossDamage, {'pang': BigNum.from(350)});
  });

  Map<String, Object?> fight() {
    final e = CoreEngine(
      tables: tables,
      clock: ManualClock(start),
      initial: GameState.newGame(playerId: 'x', seed: 1, now: start).copyWith(
        progress: const Progress(stage: 5, bestStage: 5),
        crews: const {'octo': CrewState(level: 60), 'pang': CrewState(level: 60), 'sword': CrewState(level: 60)},
        ship: const ShipState().withLevel('hull', 30), // 보스 공격 × 100(C8) — 강화 안 한 배는 보스전 중에 가라앉는다
      ),
    )..enqueue(const OpSpawnBoss());
    final events = <GameEvent>[];
    BattleView? last;
    for (var i = 0; i < 2400 && events.whereType<BossCleared>().isEmpty; i++) {
      last = e.state.battle;
      e.tick();
      events.addAll(e.drainEvents());
    }
    final cleared = events.whereType<BossCleared>().single;
    return {'cleared': cleared, 'last': last, 'json': jsonEncode(cleared.toJson())};
  }

  test('보스 처치: BossCleared에 선원별 보스 피해·MVP, 스테이지 누적(BattleView)에도 있다, 같은 시드면 같은 값', () {
    final a = fight();
    final cleared = a['cleared']! as BossCleared;
    final last = a['last']! as BattleView;
    expect(cleared.crewDamage, isNotEmpty);
    final top = cleared.crewDamage.entries.reduce((x, y) => y.value > x.value ? y : x);
    expect(cleared.mvp, top.key);
    // 마지막 틱(격파) 앞 화면 값: 보스전 선원은 모두 스테이지 누적에도 있다(격파 틱의 마지막 일격은 아직 안 들어감)
    expect(last.crewDamage.keys, containsAll(cleared.crewDamage.keys));
    final back = GameEvent.fromJson(jsonDecode(a['json']! as String) as Json) as BossCleared;
    expect(back.crewDamage, cleared.crewDamage);
    expect(back.mvp, cleared.mvp);
    expect(fight()['json'], a['json']);
  });

  test('옛 기록: crewDamage·mvp 키가 없으면 빈 맵·null, BattleView도 키 없음', () {
    final c = GameEvent.fromJson(const {'type': 'bossCleared', 't': 1, 'stage': 3, 'gems': 5}) as BossCleared;
    expect(c.crewDamage, isEmpty);
    expect(c.mvp, isNull);
    expect(BattleView.empty.toJson().containsKey('crewDamage'), isFalse);
  });
}
