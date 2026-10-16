import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/battle/topdown/boss_patterns.dart' show BossPlan;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/ads.dart' show addTailwind;
import 'package:game_core/src/economy/cards.dart';
import 'package:game_core/src/economy/offline.dart';
import 'package:game_core/src/economy/ship_stats.dart' show goldMultiplier;
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

// 항해 돌발 이벤트 (docs/specs/platform-fun-sea-events.md). 수치는 meta.seaEvents.
// 안 눌러도 손해 없음 — 끝나면 기본 보상 또는 그냥 지나간다. 오프라인에서는 일어나지 않는다(전투 틱에서만 돈다).

JsonReader _cfg(GameTables t) => t.meta.raw.obj('seaEvents');
JsonReader _event(GameTables t, String id) => _cfg(t).objs('events').firstWhere((e) => e.str('id') == id);
int _ticks(GameTables t, double sec) => (sec / (t.waves.tickMs * secondsPerMillisecond)).round();

/// 폭풍 중 처치 골드 배율 (CombatStats가 곱한다).
double stormGoldMultiplier(GameState s, GameTables t) =>
    s.battle?.seaEvent?.id == 'storm' ? _event(t, 'storm').number('goldMultiplier') : 1;

double _between(SystemContext ctx, List<dynamic> range) {
  final lo = (range[0] as num).toDouble();
  final hi = (range[1] as num).toDouble();
  return lo + ctx.rng.nextDouble() * (hi - lo);
}

/// 한 틱: 진행 중이면 끝·보상을 보고, 아니면 다음 이벤트까지 남은 시간을 줄인다(보스전·피버 중엔 멈춤).
GameState seaEventStep(GameState s, Field f, SystemContext ctx) {
  final t = ctx.tables;
  final ev = s.battle?.seaEvent;
  if (ev != null) return _tickActive(s, f, ctx, ev);
  if (s.progress.stage < _cfg(t).integer('minStage') || f.bossActive || feverOn(s)) return s;
  final left =
      (s.progress.seaEventInSec ?? _between(ctx, _cfg(t).raw['intervalSec'] as List)) -
      t.waves.tickMs * secondsPerMillisecond;
  if (left > 0) return s.copyWith(progress: s.progress.copyWith(seaEventInSec: left));
  return startSeaEvent(s, f, ctx, _pick(s, ctx));
}

/// 가중 추첨 (같은 이벤트 연속 금지).
String _pick(GameState s, SystemContext ctx) {
  final pool = [
    for (final e in _cfg(ctx.tables).objs('events'))
      if (e.str('id') != s.progress.seaEventLast) e,
  ];
  final total = pool.fold<double>(0, (a, e) => a + e.number('weight'));
  var r = ctx.rng.nextDouble() * total;
  for (final e in pool) {
    r -= e.number('weight');
    if (r < 0) return e.str('id');
  }
  return pool.last.str('id');
}

/// 이벤트 시작 (운영자 OpSeaEvent도 이것).
GameState startSeaEvent(GameState s, Field f, SystemContext ctx, String id) {
  final t = ctx.tables;
  final e = _event(t, id);
  final ticks = _ticks(t, e.number('durationSec'));
  final top = t.waves.raw.obj('top');
  final stage = s.progress.stage;
  final w = t.waves;
  // 화면 안 배 둘레 밖 고리(상자와 같은 자리 규칙)·화면 밖 접근 원.
  ({double x, double y}) ring(double r, double angle) =>
      (x: top.number('shipX') + r * math.cos(angle), y: top.number('shipY') + r * math.sin(angle));
  final near = top.number('shipRadius') + top.number('chestMargin');
  final far = math.min(top.number('viewWidth'), top.number('viewHeight')) * half - top.number('chestMargin');
  Foe foe(
    String kind,
    String eventKind,
    ({double x, double y}) at,
    BigNum hp,
    BigNum gold,
    double speed,
    BigNum attack,
  ) => Foe(
    id: f.nextId(),
    kind: kind,
    layer: 'surface',
    x: at.x,
    y: at.y,
    maxHp: hp,
    speed: speed,
    attack: attack,
    gold: gold,
    eventKind: eventKind,
  );
  final mobHp = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor);
  final mobGold = stageCurve(w.goldBase, w.goldGrowth, stage);
  final mobSpeed = t.regions.enemies.values.first.speed;
  var choices = const <String>[];
  switch (id) {
    case 'goldfish':
      final range = e.raw['count'] as List;
      final n = (range[0] as int) + ctx.rng.nextInt((range[1] as int) - (range[0] as int) + 1);
      for (var i = 0; i < n; i++) {
        final at = ring(near + ctx.rng.nextDouble() * math.max(far - near, 0), ctx.rng.nextDouble() * fullTurn);
        // 탭으로만 잡는다 — 총에 맞아도 죽지 않게(조준 제외는 TopAim이 eventKind로).
        f.foes.add(foe('goldfish', 'goldfish', at, _unkillable, mobGold.times(e.number('perFish')), 0, BigNum.zero));
      }
    case 'merchant':
      // 스쳐 지나가기: 보이는 화면 한쪽 밖 → 반대쪽 밖, 배 둘레에서 passMargin(+0~passSpread) 떨어진 가로선(위·아래 무작위).
      // durationSec 안에 건너는 속도(엔진은 passX·passY면 배율 없이 직진 — S5 TopGeometry).
      final dir = ctx.rng.nextDouble() < half ? 1.0 : -1.0;
      final side = ctx.rng.nextDouble() < half ? 1.0 : -1.0;
      final edge = top.number('viewWidth') * half + top.number('spawnMargin');
      final off = top.number('shipRadius') + e.number('passMargin') + ctx.rng.nextDouble() * e.number('passSpread');
      f.foes.add(
        Foe(
          id: f.nextId(),
          kind: 'merchant_ship',
          layer: 'surface',
          x: top.number('shipX') - dir * edge,
          y: top.number('shipY') + side * off,
          maxHp: mobHp.times(e.number('hpMultiplier')),
          speed: (edge + edge) / e.number('durationSec'),
          attack: BigNum.zero,
          gold: BigNum.zero,
          eventKind: 'merchant',
          passX: dir,
          passY: 0,
        ),
      );
    case 'ambush':
      final boss = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.bossHpMultiplier * e.number('bossHpRatio'));
      final gold = stageCurve(w.goldBase, w.goldGrowth, stage).times(w.bossGoldMultiplier * e.number('goldBossRatio'));
      final attack = stageCurve(w.attackBase, w.attackGrowth, stage).times(w.bossAttackMultiplier);
      final at = ring(top.number('approachRadius'), ctx.rng.nextDouble() * fullTurn);
      final serpent = foe('sea_serpent', 'ambush', at, boss, gold, mobSpeed, attack);
      if (e.has('patterns')) {
        // 사용자 결정(2026-10-16): 바다 괴물 = 돌진 패턴 보스 — standoff에서 돌진·복귀(boss_patterns.dart)
        serpent.plan = BossPlan(
          e.objs('patterns').map(BossPatternDef.fromJson).toList(),
          _ticks(ctx.tables, e.number('restSec')),
        );
      }
      f.foes.add(serpent);
    case 'bottle':
      choices = [for (final c in e.objs('choices')) c.str('type')];
      ctx.emit(BottleOpened(ctx.tick, choices: choices));
  }
  ctx.emit(SeaEventStarted(ctx.tick, id: id, untilTick: ctx.tick + ticks));
  final v = s.battle ?? BattleView.empty;
  return s.copyWith(
    progress: s.progress.copyWith(seaEventLast: id),
    battle: v.copyWith(
      seaEvent: SeaEventView(id: id, ticksLeft: ticks, choices: choices),
    ),
  );
}

final _unkillable = BigNum.parse('1e300');

GameState _tickActive(GameState s, Field f, SystemContext ctx, SeaEventView ev) {
  final t = ctx.tables;
  final e = _event(t, ev.id);
  final mine = f.foes.where((x) => x.eventKind == ev.id).toList();
  // 잡았는가 (상선·괴물: 처치, 물고기: 모두 탭).
  if ((ev.id == 'merchant' || ev.id == 'ambush') && mine.isNotEmpty && mine.every((x) => !x.alive)) {
    var next = s;
    if (ev.id == 'merchant') {
      next = next.copyWith(wallet: next.wallet.copyWith(gems: next.wallet.gems + e.integer('gems')));
      final owned = next.crews.keys.toList()..sort();
      for (var i = 0; i < e.integer('cards') && owned.isNotEmpty; i++) {
        next = receiveCard(
          next,
          t,
          owned[ctx.rng.nextInt(owned.length)],
          rollRarity(t.rarities.bossDropRates, ctx.rng),
        );
      }
    } else {
      next = next.copyWith(
        progress: next.progress.copyWith(rage: math.min(next.progress.rage + e.number('rage'), t.skills.rageMax)),
      );
    }
    f.foes.removeWhere((x) => x.eventKind == ev.id);
    return _end(addFever(next, t.meta.raw.obj('fever').number('seaEventWin')), ctx, ev.id, 'done');
  }
  if (ev.id == 'goldfish' && mine.isEmpty) return _end(s, ctx, ev.id, 'done');
  if (ev.ticksLeft > 1) {
    return s.copyWith(
      battle: s.battle!.copyWith(
        seaEvent: SeaEventView(id: ev.id, ticksLeft: ev.ticksLeft - 1, choices: ev.choices),
      ),
    );
  }
  // 시간이 다 됨: 물고기는 남은 마리의 autoCatchRatio(내림)를 자동으로, 유리병은 첫 쪽지, 나머지는 떠남.
  var next = s;
  var result = 'left';
  switch (ev.id) {
    case 'goldfish':
      final auto = (mine.length * e.number('autoCatchRatio')).floor();
      for (final fish in mine.take(auto)) {
        next = _catch(next, ctx, fish, auto: true);
      }
      result = 'done';
    case 'bottle':
      return pickBottleAt(next, ctx, 0, auto: true);
  }
  f.foes.removeWhere((x) => x.eventKind == ev.id);
  return _end(next, ctx, ev.id, result);
}

GameState _end(GameState s, SystemContext ctx, String id, String result) {
  ctx.emit(SeaEventEnded(ctx.tick, id: id, result: result));
  return s.copyWith(
    progress: s.progress.copyWith(seaEventInSec: _between(ctx, _cfg(ctx.tables).raw['intervalSec'] as List)),
    battle: s.battle?.copyWith(clearSeaEvent: true),
  );
}

GameState _catch(GameState s, SystemContext ctx, Foe fish, {bool auto = false}) {
  final gold = fish.gold.times(_goldMul(s, ctx.tables));
  ctx.emit(GoldfishCaught(ctx.tick, targetId: fish.id, gold: gold, auto: auto));
  return grantGold(s, ctx, gold);
}

double _goldMul(GameState s, GameTables t) =>
    goldMultiplier(t.shipParts, s.ship.level('cargo')) * (1 + damageBonus(s, t));

/// 황금 물고기 탭 (BattleSystem이 Field와 함께 부른다). 없는 id·다른 적이면 그대로.
GameState tapGoldfish(GameState s, Field f, TapSeaEvent c, SystemContext ctx) {
  final fish = f.foes.where((x) => x.id == c.targetId && x.eventKind == 'goldfish').firstOrNull;
  if (fish == null || s.battle?.seaEvent?.id != 'goldfish') return s;
  f.foes.remove(fish);
  final next = _catch(s, ctx, fish);
  return f.foes.any((x) => x.eventKind == 'goldfish') ? next : _end(next, ctx, 'goldfish', 'done');
}

/// 유리병 쪽지 고르기 (EconomySystem — PickBottle).
GameState pickBottle(GameState s, PickBottle c, SystemContext ctx) =>
    s.battle?.seaEvent?.id == 'bottle' ? pickBottleAt(s, ctx, c.index) : s;

GameState pickBottleAt(GameState s, SystemContext ctx, int index, {bool auto = false}) {
  final t = ctx.tables;
  final choices = _event(t, 'bottle').objs('choices');
  if (index < 0 || index >= choices.length) return s;
  final c = choices[index];
  var next = s;
  late final String reward;
  switch (c.str('type')) {
    case 'gold':
      final gold = goldPerSecEstimate(
        s,
        t,
        offlineFleet(s, t),
      ).times(c.number('minutesOfKills') * Duration.secondsPerMinute);
      next = grantGold(next, ctx, gold);
      reward = 'gold:$gold';
    case 'tailwind':
      next = addTailwind(next, t, ctx.clock.now(), Duration(seconds: c.integer('sec')));
      reward = 'tailwind:${c.integer('sec')}';
    default:
      next = next.copyWith(wallet: next.wallet.copyWith(gems: next.wallet.gems + c.integer('gems')));
      reward = 'gems:${c.integer('gems')}';
  }
  ctx.emit(BottlePicked(ctx.tick, index: index, reward: reward, auto: auto));
  return _end(next, ctx, 'bottle', 'done');
}
