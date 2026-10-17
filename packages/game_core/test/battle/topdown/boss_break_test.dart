import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show startBoss;
import 'package:game_core/src/battle/topdown/boss_break.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스 브레이크 게이지 (사용자 결정 2026-10-17 — '기절·끌기·취약·둔화가 쌓이고, 가득 차면 보스가 쓰러져 몇 초간 피해 ×3').
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables tables({bool on = true, num? cooldownSec}) {
    final raw = Map<String, String>.of(rawTables);
    final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>;
    if (on) {
      skills['bossBreak'] = {
        'stunPerSec': 0.5,
        'slowPerSec': 0.1,
        'vulnerablePerSec': 0.1,
        'pullPerPx': 0.01,
        'breakSec': 3,
        'damageMul': 3,
        'cooldownSec': ?cooldownSec,
      };
    } else {
      skills.remove('bossBreak');
    }
    raw['skills'] = jsonEncode(skills);
    return GameTables.load(raw);
  }

  ({Round r, Foe boss, List<GameEvent> events, SystemContext ctx, GameState s}) arena(GameTables t) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))..geometry = g;
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    startBoss(f, stage, ctx, emit: false, x: g.top.shipX, y: g.top.shipY - g.top.bossStandoff);
    final s = GameState.newGame(playerId: 'k', seed: 1, now: start);
    return (
      r: Round(f, ctx, CombatStats.of(s, t)),
      boss: f.foes.firstWhere((e) => e.boss),
      events: events,
      ctx: ctx,
      s: s,
    );
  }

  test('기절·끌기가 쌓여 가득 차면 BossBroken: breakSec 기절 + 받는 피해 × 3, 그동안 안 쌓임, 끝나면 다시 일어남', () {
    final a = arena(tables());
    a.boss.stunTimer = 1; // 기절 1초 = 0.5
    a.r.tickBossBreak();
    expect(a.boss.breakGauge, closeTo(0.5, 1e-9));
    expect(a.boss.view().breakRatio, closeTo(0.5, 1e-9));
    a.r.geo.pull(a.boss, a.boss.x + 10, a.boss.y, 50); // 끌기 50px = 0.5
    a.r.tickBossBreak();
    final broken = a.events.whereType<BossBroken>().single;
    expect(broken.ticks, 3 * 1000 ~/ a.ctx.tables.waves.tickMs);
    expect(a.boss.stunned, isTrue);
    expect(a.boss.vulnerable, closeTo(2, 1e-9), reason: '× 3 = 취약 +200%');
    expect(a.boss.view().broken, isTrue);
    expect(a.boss.breakGauge, 0);
    a.boss.stunTimer = a.boss.stunTimer + 5;
    a.r.tickBossBreak();
    expect(a.boss.breakGauge, 0, reason: '쓰러진 동안은 안 쌓인다');
    a.ctx.tick = broken.tick + broken.ticks;
    a.r.tickBossBreak();
    expect(a.boss.view().broken, isFalse);
  });

  test('쓰러진 보스는 같은 공격에 피해 × 3', () {
    final a = arena(tables());
    final hit = (x: a.boss.x, y: a.boss.y, hits: [(foe: a.boss, factor: 1.0)]);
    final hp0 = a.boss.hp.toDouble();
    a.r.strike(hit, BigNum.from(100));
    final normal = hp0 - a.boss.hp.toDouble();
    a.boss.stunTimer = 2;
    a.r.tickBossBreak();
    a.r.geo.pull(a.boss, a.boss.x + 10, a.boss.y, 100);
    a.r.tickBossBreak();
    expect(a.boss.view().broken, isTrue);
    final hp1 = a.boss.hp.toDouble();
    a.r.strike(hit, BigNum.from(100));
    expect(hp1 - a.boss.hp.toDouble(), closeTo(normal * 3, normal * 1e-9));
  });

  /// 가득 채워 쓰러뜨리고 일어나는 틱까지 돌린 뒤 ([cooldownSec]초 쿨다운 표).
  ({Round r, Foe boss, List<GameEvent> events, SystemContext ctx, GameState s}) stoodUp({num? cooldownSec}) {
    final a = arena(tables(cooldownSec: cooldownSec));
    a.boss.stunTimer = 2; // 1.0 → 쓰러짐
    a.r.tickBossBreak();
    final broken = a.events.whereType<BossBroken>().single;
    a.ctx.tick = broken.tick + broken.ticks;
    a.r.tickBossBreak(); // 일어남
    return a;
  }

  test('cooldownSec: 일어난 뒤 그 초 동안은 안 쌓이고, 지나면 다시 쌓인다', () {
    final a = stoodUp(cooldownSec: 5);
    final dt = a.ctx.tables.waves.tickMs / 1000;
    final until = a.ctx.tick + (5 / dt).round();
    a.ctx.tick += 1;
    a.boss.stunTimer = a.boss.stunTimer + 1;
    a.r.tickBossBreak();
    expect(a.boss.breakGauge, 0, reason: '쿨다운 중');
    a.ctx.tick = until;
    a.boss.stunTimer = a.boss.stunTimer + 1; // 기절 1초 = 0.5
    a.r.tickBossBreak();
    expect(a.boss.breakGauge, closeTo(0.5, 1e-9));
  });

  test('EnemyView.breakCooldown: 일어난 순간 1 → 줄어 0, 0이면 JSON에 없다', () {
    final a = stoodUp(cooldownSec: 5);
    final dt = a.ctx.tables.waves.tickMs / 1000;
    final ticks = (5 / dt).round();
    a.ctx.tick += ticks ~/ 2;
    a.r.tickBossBreak();
    expect(a.boss.view().breakCooldown, closeTo(0.5, 1 / ticks));
    expect(a.boss.view().toJson()['breakCooldown'], isNotNull);
    expect(EnemyView.fromJson(a.boss.view().toJson()).breakCooldown, a.boss.view().breakCooldown);
    a.ctx.tick += ticks;
    a.r.tickBossBreak();
    expect(a.boss.view().breakCooldown, 0);
    expect(a.boss.view().toJson().containsKey('breakCooldown'), isFalse);
  });

  test('cooldownSec가 없으면(또는 0이면) 지금 그대로 — 일어난 바로 다음 틱부터 쌓인다, 이벤트도 같다', () {
    List<String> run({num? cooldownSec}) {
      final a = stoodUp(cooldownSec: cooldownSec);
      a.ctx.tick += 1;
      a.boss.stunTimer = a.boss.stunTimer + 1;
      a.r.tickBossBreak();
      return [...a.events.map((e) => jsonEncode(e.toJson())), '${a.boss.breakGauge}'];
    }

    final none = run();
    expect(none.last, '0.5');
    expect(run(cooldownSec: 0), none);
  });

  test('둔화·취약도 쌓이고, 표에 bossBreak가 없으면 꺼짐(잡몹은 무관)', () {
    final a = arena(tables());
    a.boss
      ..slowTimer = 2
      ..vulnerableTimer = 3;
    a.r.tickBossBreak();
    expect(a.boss.breakGauge, closeTo(0.2 + 0.3, 1e-9));
    final off = arena(tables(on: false));
    off.boss.stunTimer = 10;
    off.r.tickBossBreak();
    expect(off.boss.breakGauge, 0);
    expect(off.events.whereType<BossBroken>(), isEmpty);
  });
}
