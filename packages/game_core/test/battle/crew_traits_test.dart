import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 특성 중복 정리(사용자 2026-10-17, BALANCE.md 4절): 연쇄 번개 pelly · 처형 bones · 충전 사격 volt · 추적 깃털 polly.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  final legend = t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  late List<GameEvent> events;
  setUp(() => events = []);

  var nextId = 1;
  Foe foe(double x, double y, {double hpRatio = 1}) {
    final e = Foe(
      id: nextId++,
      kind: 'crab',
      layer: 'surface',
      x: x,
      y: y,
      maxHp: BigNum.from(1e12),
      speed: 0,
      attack: BigNum.one,
      gold: BigNum.one,
    );
    e.hp = e.maxHp.times(hpRatio);
    return e;
  }

  Round round(List<Foe> foes) {
    final g = geometryFor(t, 1) as TopGeometry;
    final f = Field(stage: 1, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100))
      ..geometry = g
      ..foes.addAll(foes);
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    return Round(f, ctx, CombatStats.of(GameState.newGame(playerId: 't', seed: 1, now: start), t));
  }

  Gun gun(String id, int rarity) => Gun.of(t, id, power: 1, rarity: rarity);
  List<Damage> on(Foe e) => [...events.whereType<Damage>().where((d) => d.targetId == e.id)];
  final base = BigNum.from(1000);
  TopGeometry geo() => geometryFor(t, 1) as TopGeometry;
  ({double x, double y}) near(int i) => (x: geo().top.shipX + 30 + i * 8.0, y: geo().top.shipY - 30);

  test('연쇄 번개(pelly): 등급마다 이어지는 수 희귀 2 · 영웅 3 · 전설 5 · 신화 7, 한 번 튈 때마다 × 0.7', () {
    final counts = t.skills.legends['pelly']!.obj('arc').raw['counts'] as List;
    expect(counts.sublist(1), [2, 3, 5, 7]);
    for (final rarity in [1, 2, legend, legend + 1]) {
      events.clear();
      final foes = [for (var i = 0; i < 10; i++) foe(near(i).x, near(i).y)];
      final r = round(foes);
      final g = gun('pelly', rarity);
      lightningArc(r, g, (x: foes.first.x, y: foes.first.y, hits: [(foe: foes.first, factor: 1.0)]), base);
      final hit = [
        for (final e in foes.skip(1))
          if (on(e).isNotEmpty) e,
      ];
      expect(hit, hasLength(counts[rarity]), reason: 'rarity $rarity');
      final first = on(hit[0]).single.amount.toDouble();
      expect(on(hit[1]).single.amount.toDouble(), closeTo(first * 0.7, first * 1e-6));
    }
  });

  test('처형(bones): 맞은 뒤 HP 30% 아래 적에게만 피해 × (mul − 1)을 더', () {
    final low = foe(near(0).x, near(0).y, hpRatio: 0.2);
    final high = foe(near(1).x, near(1).y, hpRatio: 0.8);
    final r = round([low, high]);
    execute(r, gun('bones', legend), (
      x: low.x,
      y: low.y,
      hits: [(foe: low, factor: 1.0), (foe: high, factor: 1.0)],
    ), base);
    expect(on(low), hasLength(1));
    expect(on(high), isEmpty);
  });

  test('충전 사격(volt): every번째로 맞힌 발에만 추가 피해 + 기절', () {
    final e = foe(near(0).x, near(0).y);
    final r = round([e]);
    final g = gun('volt', legend);
    final every = g.legend!.charge!.every;
    for (var i = 1; i <= every; i++) {
      chargedShot(r, g, (x: e.x, y: e.y, hits: [(foe: e, factor: 1.0)]), base);
      expect(on(e), hasLength(i == every ? 1 : 0), reason: 'shot $i');
    }
    expect(e.stunned, isTrue);
    expect(gun('volt', legend).legend!.extraChains, 0, reason: '연쇄는 pelly 대표로');
  });

  test('추적 깃털(polly): 전설은 늘 빗나가지 않고, 일반은 발마다 확률(traitScale)', () {
    expect(missProof(gun('polly', legend), XorShiftRng(1)), isTrue);
    final common = gun('polly', 0);
    final rng = XorShiftRng(2);
    final n = [for (var i = 0; i < 1000; i++) missProof(common, rng)].where((b) => b).length;
    expect(n / 1000, closeTo(t.skills.traitScale[0], 0.05));
    expect(gun('polly', legend).legend!.extraChains, 0);
  });
}
