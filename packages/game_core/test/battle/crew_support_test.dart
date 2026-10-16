import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/economy/fever.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 선원 개성 v2 3단계 (기획서 7절): 보호막(turtle)·낙뢰(pelly)·피버 서포트(pumpum). 표 값은 기획 제안(S2 표 전 테스트 값).
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;
  final raw = Map<String, String>.of(rawTables);
  final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>;
  final legends = skills['legends'] as Map<String, dynamic>;
  legends['turtle'] = {
    'shield': {'everySec': 8, 'durationSec': 4, 'hpRatio': 0.25},
  };
  legends['pelly'] = {
    'arc': {'count': 3, 'ratio': 0.35, 'stunSec': 0.2},
  };
  legends['pumpum'] = {
    'fever': {'chargeBonus': 0.5, 'extraSec': 5},
  };
  skills['traitScale'] = [0.4, 0.6, 0.8];
  raw['skills'] = jsonEncode(skills);
  final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
  for (final c in (crews['crews'] as List).cast<Map<String, dynamic>>()) {
    if (c['id'] == 'pelly') {
      c['aim'] = {
        'shape': 'circle',
        'topRadius': 22,
        'targets': 'nearest',
        'intervalSec': 30,
        'kind': 'lightning',
        'projectile': {'delaySec': 0.4},
        'behavior': {'kind': 'lightning'}, // 공중 계열 출격(계열 v3)에서 빠진다 — 실제 표와 같게
      };
    }
  }
  raw['crews'] = jsonEncode(crews);
  final t = GameTables.load(raw);
  final legend = t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  final s = GameState.newGame(playerId: 'c', seed: 1, now: start).copyWith(
    progress: const Progress(stage: stage, bestStage: stage),
  );
  final g = geometryFor(t, stage) as TopGeometry;

  Foe foe(int id, double dx, double dy, {double speed = 0}) => Foe(
    id: id,
    kind: 'crab',
    layer: 'surface',
    x: g.top.shipX + dx,
    y: g.top.shipY + dy,
    maxHp: BigNum.from(1000000000000),
    speed: speed,
    attack: BigNum.from(50),
    gold: BigNum.one,
  );

  List<GameEvent> fight(Field f, double seconds) {
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    final stats = CombatStats.of(s, t);
    for (var i = 0; i < (seconds * 1000 / t.waves.tickMs).round(); i++) {
      ctx.tick = i;
      Round(f, ctx, stats, rage: 0)
        ..moveFoes()
        ..fireGuns()
        ..topdownStep(s);
    }
    return events;
  }

  Field field(String crew, int rarity, List<Foe> foes) =>
      Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))
        ..geometry = g
        ..guns = [Gun.of(t, crew, power: 1, rarity: rarity)]
        ..foes.addAll(foes);

  test('보호막: 첫 틱·everySec마다 배 HP × hpRatio(일반 × 0.4) 막, 피해를 먼저 받고 다 깎이면 depleted', () {
    final f = field('turtle', legend, []);
    final events = fight(f, 0.1);
    final up = events.whereType<ShieldUp>().single;
    expect(up.hp.toDouble(), closeTo(250, 1e-6));
    expect(up.ticks, 4 * 1000 ~/ t.waves.tickMs);
    expect(f.view(BattleView.empty).shipShield, 1);
    final lost = f.hurtShip(BigNum.from(60), 1);
    expect(lost.isZero, isTrue, reason: '막이 다 받음');
    expect(f.shipHp.toDouble(), 1000);
    expect(f.view(BattleView.empty).shipShield, closeTo(190 / 250, 1e-9));
    expect(f.hurtShip(BigNum.from(300), 1).toDouble(), closeTo(110, 1e-6), reason: '남은 190을 넘는 몫만 배로');
    expect(fight(f, 0.1).whereType<ShieldBroken>().single.reason, 'depleted');
    final common = field('turtle', 0, []);
    expect(fight(common, 0.1).whereType<ShieldUp>().single.hp.toDouble(), closeTo(1000 * 0.25 * 0.4, 1e-6));
  });

  test('보호막: 시간이 끝나면 expired, 8초 뒤 다시', () {
    final f = field('turtle', legend, []);
    final events = fight(f, 8.2);
    expect(events.whereType<ShieldUp>(), hasLength(2));
    expect(events.whereType<ShieldBroken>().single.reason, 'expired');
  });

  test('낙뢰: 예고 0.4초 뒤 쏠 때의 자리에 떨어지고(kind lightning) 가까운 적 3마리에 × 0.35 연쇄', () {
    final target = foe(1, 0, -80);
    final f = field('pelly', legend, [target, foe(2, 30, -80), foe(3, -30, -80), foe(4, 0, -120), foe(5, 70, -110)]);
    final events = fight(f, 1);
    final fired = events.whereType<AttackFired>().single;
    expect(fired.kind, 'lightning');
    expect(fired.flightTicks, 400 ~/ t.waves.tickMs);
    final dmg = events.whereType<Damage>().toList();
    expect(dmg.first.tick - fired.tick, fired.flightTicks);
    final first = dmg.firstWhere((d) => d.targetId == 1).amount.toDouble();
    final arcs = dmg.where((d) => d.targetId != 1 && d.tick == dmg.first.tick).toList();
    expect(arcs.length, greaterThanOrEqualTo(3), reason: '원 안 + 연쇄 3');
    expect(arcs.map((d) => d.amount.toDouble()).reduce((a, b) => a < b ? a : b), lessThan(first));
  });

  test('낙뢰는 자리에 떨어진다: 빠르게 다가오는 적은 빗나갈 수 있다(MISS)', () {
    final runner = foe(1, 0, -150, speed: 60);
    final events = fight(field('pelly', legend, [runner]), 1);
    expect(events.whereType<AttackMissed>(), hasLength(1));
  });

  test('피버 서포트: 출전 중이면 충전 × (1 + 0.5), 지속 + 5초 — 일반은 × 0.4', () {
    GameState withPumpum(int level) => s.copyWith(
      crews: {'pumpum': CrewState(level: level)},
      fleet: const ['pumpum'],
    );
    final legendLevel = t.rarities.rarities[legend].levelMin;
    final sup = feverSupport(withPumpum(legendLevel), t);
    expect(sup.charge, closeTo(0.5, 1e-9));
    expect(sup.extraSec, closeTo(5, 1e-9));
    final weak = feverSupport(withPumpum(1), t);
    expect(weak.charge, closeTo(0.2, 1e-9));
    expect(weak.extraSec, closeTo(2, 1e-9));
    expect(feverSupport(s, t).charge, 0, reason: '출전 안 함');
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {});
    final kills = feverKillsAt(t, stage);
    final full = feverStep(withPumpum(legendLevel), ctx, kills: (kills / 1.5).ceil(), bossKilled: false);
    expect(
      full.battle!.feverTicksLeft,
      ((t.meta.raw.obj('fever').number('durationSec') + 5) * 1000 / t.waves.tickMs).round(),
    );
  });
}
