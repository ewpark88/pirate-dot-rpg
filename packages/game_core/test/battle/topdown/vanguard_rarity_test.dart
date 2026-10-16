import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show spawnWave;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 사용자 결정(2026-10-16, S1·S2): 돌격대(파밍 파 배 피해) · 전설 이상 공속·신화 맞은 자리 폭발.
void main() {
  final start = DateTime.utc(2026, 11);

  GameTables patched(
    void Function(Map<String, dynamic> waves, Map<String, dynamic> skills, List<Map<String, dynamic>> crews) f,
  ) {
    final raw = Map<String, String>.of(rawTables);
    final waves = jsonDecode(raw['waves']!) as Map<String, dynamic>;
    final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>;
    final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
    f(waves, skills, (crews['crews'] as List).cast<Map<String, dynamic>>());
    raw
      ..['waves'] = jsonEncode(waves)
      ..['skills'] = jsonEncode(skills)
      ..['crews'] = jsonEncode(crews);
    return GameTables.load(raw);
  }

  final t = patched((w, s, c) {
    (w['top'] as Map<String, dynamic>)['vanguard'] = {'count': 2, 'hpMul': 4, 'speedMul': 1.6, 'fromStage': 5};
    s['rarityTempo'] = [1, 1, 1, 0.9, 0.8];
    c.firstWhere((x) => x['id'] == 'pang')['aim'] = {
      'intervalSec': 1.2,
      'mythic': {'splashRadius': 14, 'splashRatio': 0.5},
    };
  });
  final legend = t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  final mythic = t.rarities.rarities.indexWhere((r) => r.id == 'mythic');

  Field field(int stage) {
    final g = geometryFor(t, stage) as TopGeometry;
    return Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))..geometry = g;
  }

  SystemContext ctx(List<GameEvent> out) =>
      SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(2), onEvent: out.add);

  group('돌격대', () {
    test('파마다 count마리, HP × 4·속도 × 1.6(그 파 무리 한 마리 본떠), fromStage 전·소환은 없음', () {
      final f = field(10);
      spawnWave(f, 10, ctx([]));
      final v = f.foes.where((e) => e.vanguard).toList();
      final mob = f.foes.firstWhere((e) => !e.vanguard);
      expect(v, hasLength(2));
      expect(v.first.maxHp.toDouble(), closeTo(mob.maxHp.toDouble() * 4, 1e-6));
      expect(v.first.speed, closeTo(mob.speed * 1.6, 1e-9));
      expect(v.first.view().vanguard, isTrue);
      expect(mob.view().toJson().containsKey('vanguard'), isFalse);
      final early = field(3);
      spawnWave(early, 3, ctx([]));
      expect(early.foes.where((e) => e.vanguard), isEmpty);
      final summoned = field(10);
      spawnWave(summoned, 10, ctx([]), count: 3);
      expect(summoned.foes.where((e) => e.vanguard), isEmpty);
    });

    test('넉백·기절·끌기 면역 — 맞아도 그대로 배로 와서 박는다(한 대 상한)', () {
      final f = field(10);
      final events = <GameEvent>[];
      final c = ctx(events);
      spawnWave(f, 10, c);
      f.foes.removeWhere((e) => !e.vanguard);
      final e = f.foes.first;
      final g = f.geometry! as TopGeometry;
      final s = GameState.newGame(playerId: 'v', seed: 1, now: start);
      final r = Round(f, c, CombatStats.of(s, t), rage: 0);
      final before = (x: e.x, y: e.y);
      r.control([e], knockback: 50, stunSec: 3);
      g.pull(e, e.x + 30, e.y, 30);
      expect((x: e.x, y: e.y), before);
      expect(e.stunned, isFalse);
      for (var i = 0; i < 400 && events.whereType<ShipDamaged>().isEmpty; i++) {
        c.tick = i;
        Round(f, c, CombatStats.of(s, t), rage: 0).moveFoes();
      }
      final hit = events.whereType<ShipDamaged>().first;
      expect(hit.amount.toDouble(), lessThanOrEqualTo(1000 * t.waves.raw.number('shipHitCap') + 1e-6));
      expect(
        math.sqrt(math.pow(e.x - g.top.shipX, 2) + math.pow(e.y - g.top.shipY, 2)),
        lessThan(g.top.approachRadius),
      );
    });
  });

  group('전설 이상', () {
    test('rarityTempo: 전설 × 0.9·신화 × 0.8 간격, power는 그대로(DPS 오름)', () {
      final epic = Gun.of(t, 'pang', power: 1, rarity: legend - 1).attack;
      final leg = Gun.of(t, 'pang', power: 1, rarity: legend).attack;
      final myth = Gun.of(t, 'pang', power: 1, rarity: mythic).attack;
      final ladder = Gun.of(t, 'pang', power: 1, rarity: mythic);
      expect(leg.intervalSec, closeTo(1.2 * 0.9, 1e-9));
      expect(myth.intervalSec, closeTo(1.2 * 0.8, 1e-9));
      expect(epic.intervalSec, closeTo(1.2, 1e-9));
      final noTempo = patched((w, s, c) {
        c.firstWhere((x) => x['id'] == 'pang')['aim'] = {'intervalSec': 1.2};
      });
      expect(ladder.attack.power, closeTo(Gun.of(noTempo, 'pang', power: 1, rarity: mythic).attack.power, 1e-9));
    });

    test('aim.mythic의 splashRadius: 신화만 맞은 자리 폭발(× 0.5), AttackFired.splashRadius', () {
      expect(Gun.of(t, 'pang', power: 1, rarity: legend).attack.raw.has('splashRadius'), isFalse);
      final f = field(10)..guns = [Gun.of(t, 'pang', power: 1, rarity: mythic)];
      final g = f.geometry! as TopGeometry;
      Foe foe(int id, double dx, double dy) => Foe(
        id: id,
        kind: 'crab',
        layer: 'surface',
        x: g.top.shipX + dx,
        y: g.top.shipY + dy,
        maxHp: BigNum.from(1000000000000),
        speed: 0,
        attack: BigNum.zero,
        gold: BigNum.one,
      );
      f.foes.addAll([foe(1, 0, -70), foe(2, 8, -74), foe(3, 60, -70)]);
      final events = <GameEvent>[];
      final c = ctx(events);
      Round(f, c, CombatStats.of(GameState.newGame(playerId: 'm', seed: 1, now: start), t), rage: 0).fireGuns();
      expect(events.whereType<AttackFired>().single.splashRadius, 14);
      final dmg = {for (final d in events.whereType<Damage>()) d.targetId: d.amount.toDouble()};
      expect(dmg.keys.toSet(), {1, 2}, reason: '옆 8px만 폭발에, 60px은 아님');
      expect(dmg[2]! / dmg[1]!, closeTo(0.5, 1e-6));
    });
  });
}
