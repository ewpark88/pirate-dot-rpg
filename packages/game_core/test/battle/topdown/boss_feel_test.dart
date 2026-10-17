import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/captain_skill.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show startBoss;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스전 손맛 (사용자 '보스전도 너무 밋밋해' 2026-10-17, S1 승인 boss-feel):
/// ① 체력 층 waves.boss.bars → 층마다 BossBarBroken + 비틀, ② 선장 필살기 meta.captainSkill(자동·버튼) → UltimateCast + 폭주.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  final bars = t.waves.raw.obj('boss').obj('bars');
  final cap = t.meta.raw.obj('captainSkill');

  ({Round r, Field f, List<GameEvent> events}) arena(int stage) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1e9), shipHp: BigNum.from(1e9))..geometry = g;
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    startBoss(f, stage, ctx, emit: false, x: g.top.shipX, y: g.top.shipY - g.top.bossStandoff);
    final s = GameState.newGame(playerId: 'b', seed: 1, now: start);
    return (r: Round(f, ctx, CombatStats.of(s, t)), f: f, events: events);
  }

  test('층 수는 스테이지로: 1~29 3층 · 30~79 4층 · 80+ 5층', () {
    expect(bossBarsAt(t, 1), 3);
    expect(bossBarsAt(t, 29), 3);
    expect(bossBarsAt(t, 30), 4);
    expect(bossBarsAt(t, 80), 5);
    final a = arena(30);
    final boss = a.f.foes.firstWhere((e) => e.boss);
    expect(boss.view().bossBars, 4);
    expect(boss.view().bossBarsLeft, 4);
  });

  test('층이 깨지면 BossBarBroken(한 번에 두 층이면 둘) + staggerSec 비틀(기절·받는 피해 × staggerDamageMul)', () {
    final a = arena(10);
    final boss = a.f.foes.firstWhere((e) => e.boss);
    boss.hp = boss.maxHp.times(0.6); // 3층 → 2층
    a.r.tickBossBars();
    final ev = a.events.whereType<BossBarBroken>().single;
    expect((ev.bar, ev.barsLeft), (3, 2));
    expect(boss.stunned, isTrue);
    expect(boss.vulnerable, closeTo(bars.number('staggerDamageMul') - 1, 1e-9));
    expect(boss.stunTimer, closeTo(bars.number('staggerSec'), 1e-9));
    boss.hp = boss.maxHp.times(0.1); // 2층 → 1층(마지막 층은 처치 때 — 이벤트 없음)
    a.r.tickBossBars();
    expect(a.events.whereType<BossBarBroken>().map((e) => e.barsLeft), [2, 1]);
    a.r.tickBossBars();
    expect(a.events.whereType<BossBarBroken>(), hasLength(2), reason: '같은 층은 한 번만');
  });

  GameState fresh({bool auto = true}) {
    final s = GameState.newGame(
      playerId: 'c',
      seed: 2,
      now: start,
      crews: t.meta.startingCrews,
    ).copyWith(clearTutorial: true);
    return auto ? s : s.copyWith(settings: s.settings.withValue('autoUltimate', false));
  }

  test('자동 필살기(기본): 처치로 게이지가 차면 바로 UltimateCast(manual false) + 폭주, 게이지는 0으로', () {
    expect(fresh().settings.autoUltimate, isTrue);
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: fresh())
      ..enqueue(const OpSetInvincible(on: true));
    final casts = <UltimateCast>[];
    var maxGauge = 0.0;
    for (var i = 0; i < 6000 && casts.isEmpty; i++) {
      e.tick();
      casts.addAll(e.drainEvents().whereType<UltimateCast>());
      final g = e.state.battle!.captainGauge;
      if (g > maxGauge) maxGauge = g;
    }
    expect(casts, isNotEmpty, reason: '게이지가 찼다(최대 $maxGauge)');
    expect(casts.first.manual, isFalse);
    expect(e.state.battle!.captainGauge, lessThan(0.05));
  });

  test('자동 끔: 게이지가 가득이어도 안 쓰고, TriggerUltimate를 누르면 manual true', () {
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: fresh(auto: false))
      ..enqueue(const OpSetInvincible(on: true));
    var full = false;
    for (var i = 0; i < 6000 && !full; i++) {
      e.tick();
      expect(e.drainEvents().whereType<UltimateCast>().where((c) => c.manual), isEmpty);
      full = e.state.battle!.captainGauge >= 1;
    }
    expect(full, isTrue);
    e.enqueue(const TriggerUltimate());
    final casts = <UltimateCast>[];
    for (var i = 0; i < 3; i++) {
      e.tick();
      casts.addAll(e.drainEvents().whereType<UltimateCast>());
    }
    expect(casts.where((c) => c.manual), hasLength(1));
    expect(e.state.battle!.captainGauge, 0);
  });

  test('JSON 왕복: BossBarBroken · UltimateCast.manual · Settings.autoUltimate · captainGauge', () {
    const ev = BossBarBroken(3, enemyId: 7, bar: 3, barsLeft: 2, x: 1, y: 2);
    expect(GameEvent.fromJson(ev.toJson()).toJson(), ev.toJson());
    const u = UltimateCast(4, crewId: 'octo', ultimateId: 'tsunami', manual: true);
    expect(GameEvent.fromJson(u.toJson()).toJson(), u.toJson());
    final s = fresh(auto: false).settings;
    expect(Settings.fromJson(s.toJson()).autoUltimate, isFalse);
    expect(fresh().settings.toJson().containsKey('autoUltimate'), isFalse, reason: '기본은 키 없음(옛 세이브 그대로)');
    const v = BattleView(tick: 1, shipHp: BigNum.one, shipHpMax: BigNum.one, captainGauge: 0.5);
    expect(BattleView.fromJson(v.toJson()).captainGauge, 0.5);
    expect(cap.number('rushSec'), greaterThan(0));
  });
}
