import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 계열 행동 v3 출격(강습·공중 — 사용자 '본인이 폭탄이 되어 나가서 잡고 돌아오고, 쿨은 길게').
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables sortieTables({bool on = true}) {
    final raw = Map<String, String>.of(rawTables);
    final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>;
    final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
    for (final c in (crews['crews'] as List).cast<Map<String, dynamic>>()) {
      c.remove('aim'); // 계열 공격만 본다
    }
    for (final f in (skills['families'] as List).cast<Map<String, dynamic>>()) {
      (f['attack'] as Map<String, dynamic>).remove('behavior'); // 실제 표의 출격(강습·공중)을 지우고 이 테스트가 정한다
      if (f['id'] == 'assault' && on) {
        (f['attack'] as Map<String, dynamic>)['behavior'] = {
          'kind': 'sortie',
          'outSec': 0.35,
          'strikeSec': 0.25,
          'backSec': 0.35,
        };
      }
    }
    raw
      ..['skills'] = jsonEncode(skills)
      ..['crews'] = jsonEncode(crews);
    return GameTables.load(raw);
  }

  List<GameEvent> fight(GameTables t, double seconds, {bool killFirst = false}) {
    final g = geometryFor(t, stage) as TopGeometry;
    Foe foe(int id, double dy) => Foe(
      id: id,
      kind: 'crab',
      layer: 'surface',
      x: g.top.shipX,
      y: g.top.shipY + dy,
      maxHp: BigNum.from(1000000000000),
      speed: 0,
      attack: BigNum.zero,
      gold: BigNum.one,
    );
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))
      ..geometry = g
      ..guns = [Gun.of(t, 'shark', power: 1)]
      ..foes.addAll([foe(1, -40), foe(2, -60)]);
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    final s = GameState.newGame(playerId: 's', seed: 1, now: start);
    for (var i = 0; i < (seconds * 1000 / t.waves.tickMs).round(); i++) {
      ctx.tick = i;
      if (killFirst && events.whereType<CrewSortie>().length == 1) f.foes.first.hp = BigNum.zero;
      Round(f, ctx, CombatStats.of(s, t), rage: 0)
        ..fireGuns()
        ..topdownStep(s);
    }
    return events;
  }

  final t = sortieTables();
  int ticks(double sec) => (sec * 1000 / t.waves.tickMs).round();

  test('출격: AttackFired(flightTicks = 날아감) → out → strike(그때 피해) → back, 틱 간격대로', () {
    final ev = fight(t, 2);
    final fired = ev.whereType<AttackFired>().first;
    final s = ev.whereType<CrewSortie>().toList();
    expect(s.take(3).map((e) => e.phase), ['out', 'strike', 'back']);
    expect(fired.flightTicks, ticks(0.35));
    expect(s[0].tick, fired.tick);
    expect(s[1].tick - s[0].tick, ticks(0.35));
    expect(s[2].tick - s[1].tick, ticks(0.25));
    expect((s[0].toX, s[0].toY), (fired.x, fired.y));
    final dmg = ev.whereType<Damage>().first;
    expect(dmg.tick, s[1].tick, reason: '꽂히는 순간 맞는다');
  });

  test('쿨은 돌아온 뒤부터: 다음 발사 = 복귀 끝 + 간격(÷ 돛 공격 속도)', () {
    final ev = fight(t, 8);
    final fires = ev.whereType<AttackFired>().toList();
    final backs = ev.whereType<CrewSortie>().where((e) => e.phase == 'back').toList();
    final home = backs.first.tick + backs.first.ticks;
    final interval = Gun.of(t, 'shark', power: 1).attack.intervalSec;
    final speed = CombatStats.of(GameState.newGame(playerId: 's', seed: 1, now: start), t).attackSpeed;
    expect(fires[1].tick - home, closeTo(interval / speed / (t.waves.tickMs / 1000), 2));
  });

  test('조준한 적이 날아가는 동안 쓰러지면 꽂힌 자리 가장 가까운 적을 친다', () {
    final ev = fight(t, 1, killFirst: true);
    final strike = ev.whereType<CrewSortie>().firstWhere((e) => e.phase == 'strike');
    final hit = ev.whereType<Damage>().where((d) => d.tick == strike.tick).map((d) => d.targetId);
    expect(hit, contains(2));
  });

  test('behavior 없으면 지금처럼 즉시(출격 이벤트 없음), CrewSortie JSON 왕복', () {
    final ev = fight(sortieTables(on: false), 2);
    expect(ev.whereType<CrewSortie>(), isEmpty);
    expect(ev.whereType<AttackFired>().first.flightTicks, isNull);
    const e = CrewSortie(3, crewId: 'shark', phase: 'out', fromX: 1, fromY: 2, toX: 3, toY: 4, ticks: 7);
    expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
  });
}
