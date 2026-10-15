import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 부위 외형 단계 (사용자 지시 2026-10-15): 강화가 특정 레벨에 닿으면 배 디자인이 바뀐다.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  test('모든 부위에 외형 단계 레벨이 있고, 1부터 오름차순, 최대 레벨 안', () {
    for (final p in t.shipParts.parts) {
      expect(p.visualStages, isNotEmpty, reason: p.id);
      expect(p.visualStages.first, 1, reason: p.id);
      for (var i = 1; i < p.visualStages.length; i++) {
        expect(p.visualStages[i], greaterThan(p.visualStages[i - 1]), reason: p.id);
      }
      if (p.maxLevel case final max?) expect(p.visualStages.last, lessThanOrEqualTo(max), reason: p.id);
    }
  });

  test('검증기: 오름차순이 아니면 실패', () {
    final m = jsonDecode(rawTables['ship_parts']!) as Map<String, dynamic>;
    ((m['parts'] as List).first as Map)['visualStages'] = [1, 30, 20];
    expect(
      () => GameTables.load({...rawTables, 'ship_parts': jsonEncode(m)}),
      throwsA(isA<TableValidationException>().having((e) => e.errors.join(), 'errors', contains('visualStages'))),
    );
  });

  test('partLookStage = 레벨 이하인 외형 단계 레벨 수 (Lv0 = 0단계)', () {
    final cannon = t.shipParts.byId('cannon');
    final v = cannon.visualStages;
    expect(partLookStage(cannon, 0), 0);
    expect(partLookStage(cannon, v.first), 1);
    expect(partLookStage(cannon, v[1] - 1), 1);
    expect(partLookStage(cannon, v[1]), 2);
    expect(partLookStage(cannon, v.last + 1000), v.length);
  });

  test('partLook: 모든 부위의 단계 맵', () {
    final s = h.newGame().copyWith(ship: const ShipState(parts: {'cannon': 1}));
    final look = partLook(s, t);
    expect(look.keys.toSet(), shipPartIds.toSet());
    expect(look['cannon'], 1);
    expect(look['hull'], 0);
  });

  group('강화 → ShipLookChanged', () {
    GameState rich(Map<String, int> parts) =>
        h.newGame(gold: BigNum.parse('1e30')).copyWith(ship: ShipState(parts: parts));

    test('외형 단계 레벨에 닿으면 새 단계로 이벤트 1개, 사이 레벨에서는 없음', () {
      final second = t.shipParts.byId('cannon').visualStages[1];
      sys.handle(rich({'cannon': second - 2}), const UpgradePart('cannon'), h.ctx);
      expect(h.of<ShipLookChanged>(), isEmpty);
      sys.handle(rich({'cannon': second - 1}), const UpgradePart('cannon'), h.ctx);
      expect(h.of<ShipLookChanged>().single.part, 'cannon');
      expect(h.of<ShipLookChanged>().single.stage, 2);
    });

    test('한 번에 여러 단계를 넘으면 마지막 단계로 이벤트 1개', () {
      final v = t.shipParts.byId('cargo').visualStages;
      sys.handle(rich({'cargo': 0}), UpgradePart('cargo', times: v[2]), h.ctx);
      expect(h.of<ShipLookChanged>().single.stage, 3);
    });
  });

  test('전투 화면 BattleView.shipLook = partLook (렌더용)', () {
    final now = DateTime.utc(2026, 11);
    final s0 = GameState.newGame(
      playerId: 'p',
      seed: 1,
      now: now,
      crews: t.meta.startingCrews,
    ).copyWith(ship: const ShipState(parts: {'cannon': 1, 'sail': 1}));
    final e = CoreEngine(tables: t, clock: ManualClock(now), initial: s0)..tick();
    expect(e.state.battle!.shipLook, partLook(e.state, t));
    expect(e.state.battle!.shipLook['sail'], 1);
  });

  test('계약 JSON 왕복: ShipLookChanged, BattleView.shipLook (없으면 빈 맵)', () {
    const ev = ShipLookChanged(9, part: 'hull', stage: 3);
    expect(GameEvent.fromJson(ev.toJson()).toJson(), ev.toJson());
    const view = BattleView(shipHp: BigNum.one, shipHpMax: BigNum.one, shipLook: {'cannon': 2});
    expect(BattleView.fromJson(view.toJson()).shipLook, {'cannon': 2});
    final old = view.toJson()..remove('shipLook');
    expect(BattleView.fromJson(old).shipLook, isEmpty);
  });
}
