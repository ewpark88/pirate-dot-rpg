import 'dart:ui';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart' show parseArgb;
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

/// 지루함 해소 3종(S2 c5193fa) 연출 — 피버 시작 번쩍·흔들림, 황금 물고기 잡힘(금화 터짐 + 금 숫자 + 금화가 배로),
/// 유리병 고름 반짝임, 돌발 이벤트 시작 소리. 그림(피버 테두리·금화 비·폭풍·유리병)은 TopScenePainter가 BattleView를 보고 그린다.
/// 이 함수가 처리한 이벤트면 true.
bool funEvent(BattleScene s, GameEvent e) {
  switch (e) {
    case ShieldUp():
      s.topHits.crew.upAt = s.clockMs;
    case ShieldBroken():
      s.topHits.crew.brokenAt = s.clockMs;
      s.shake.trigger(s.juice.shake['aoe']!);
    case FastSailStarted(:final from, :final to):
      s.topHits.fast.started(from, to, s.clockMs);
      _sfx(s, 'fastSailStarted', e);
    case FastSailEnded(:final from, :final to):
      s.topHits.fast.ended(from, to, s.clockMs); // 팡파르는 UI 끝 요약 창(S4)
    case BreakthroughStrike(:final x, :final y, :final combo, :final phase, :final speed):
      s.topHits.fast.strike(x, y, combo, phase, speed, s.clockMs);
      _sfx(s, 'breakthroughStrike', e);
      s.topHits.impact.add(x, y, phase == 'finale' ? 90 : 50, 0xFFFFD84A, s.clockMs + (phase == 'finale' ? 600 : 160));
      if (phase == 'finale') s.slowMoMs = 600;
      s.shake.trigger(s.juice.shake[phase == 'finale' ? 'ultimate' : 'aoe']!);
    case BountyStarted(:final bossId, :final tier):
      s.topHits.bounty.started(bossId, tier, s.clockMs);
      _sfx(s, 'bossSpawned', e);
    case BountyCleared(:final reward):
      s.topHits.bounty.cleared(reward.type, reward.amount, _bossAt(s), s.clockMs);
      _sfx(s, 'bossCleared', e);
    case BountyFailed():
      s.topHits.bounty.failed(_bossAt(s), s.clockMs);
      _sfx(s, 'bossFailed', e);
    case BombletBurst(:final x, :final y, :final radius):
      s.topHits.impact.add(x, y, radius, 0xFFFF8A2A, s.clockMs);
    // 보물상자 열림·광고 보상(피드백 #15): 전장에서 보상이 튀어나오는 임팩트.
    case ChestOpened(:final gold) when s.isTop:
      final at = Offset(s.chest.x, s.chest.y);
      s.topHits.loot.chest(s.clockMs, at, lite: s.topHits.lite || s.settings.powerSave, gems: gold.isZero);
      if (!gold.isZero) s.numbers.add(gold, at.dx, at.dy - 16, DamageKind.crit);
      s.haptic(HapticLevel.light);
      _sfx(s, 'chestOpened', e);
    case SaveRequested(reason: 'adReward') when s.isTop:
      s.topHits.loot.reward(s.clockMs, s.topShip);
      _sfx(s, 'adReward', e);
    // 손맛 v4: 한꺼번에 5마리 이상 — 가장자리 금빛 + 작은 흔들림.
    case MultiKill(:final count) when s.isTop && count >= 5:
      if (s.settings.flash && s.screenFlashMs <= 0) s.screenFlashMs = 140;
      s.shake.trigger(s.juice.shake['aoe']!);
    // 도감 v2 보스 패턴: 먹물·삼키기·분열·자폭.
    case InkCloud(:final x, :final y, :final radius, :final ticks) when s.isTop:
      s.topHits.bestiary.ink(x, y, radius, ticks * s.player.tickMs, s.clockMs);
    case BossSwallowed(:final enemyId, :final eaten) when s.isTop:
      final boss = s.poseOf(enemyId);
      if (boss != null) {
        s.topHits.bestiary.gulp(Offset(boss.drawX, boss.drawY), [
          for (final id in eaten)
            if (s.poseOf(id) case final p?) Offset(p.drawX, p.drawY),
        ], s.clockMs);
      }
    case BossSplit(:final parentId, :final x, :final y) when s.isTop:
      final from = s.poseOf(parentId);
      s.topHits.bestiary.split(from == null ? Offset(x, y) : Offset(from.drawX, from.drawY), Offset(x, y), s.clockMs);
      s.shake.trigger(s.juice.shake['aoe']!);
    case BomberBlast(:final x, :final y, :final radius, :final onShip) when s.isTop:
      s.topHits.impact.add(x, y, radius, 0xFFFF7A2A, s.clockMs);
      s.shake.trigger(s.juice.shake[onShip ? 'bossKill' : 'aoe']!);
    // 빠른 항해 보급: 오른 부위마다 낙하산 상자가 배로 — 닿으면 그 부위가 빛난다(문구는 UI 요약 창).
    case ShipResupplied(:final before, :final after) when s.isTop:
      s.topHits.resupply
        ..onLand = s.moments.onPartUp
        ..start(s.clockMs, [
          for (final p in after.keys)
            if ((after[p] ?? 0) > (before[p] ?? 0)) p,
        ]);
      _sfx(s, 'shipLookChanged', e);
    // 보스 브레이크(사용자 '잘 안 보여'): 충격파·조각·'BREAK!' 도장·기우뚱·별, 짧은 슬로모션·흔들림.
    case BossBroken(:final enemyId, :final ticks, :final x, :final y) when s.isTop:
      s.topHits.breaks.broken(enemyId, x, y, ticks * s.player.tickMs, s.clockMs);
      s.shake.trigger(s.juice.shake['bossKill']!);
      if (s.slowMoMs <= 0) s.slowMoMs = 250;
      s.haptic(HapticLevel.medium);
      _sfx(s, 'bossBroken', e);
    // 카드 획득(피드백 #17): 보스 보상 터짐에 붙거나 배 앞에서 솟아 배로. 첫 동료는 크게 '새 동료!', 환영(starter)은 더 크게.
    case CardGranted(:final crewId, :final rarity, :final source, :final isNew) when s.isTop:
      final rs = s.tables.rarities.rarities;
      final r = rs.firstWhere((x) => x.id == rarity, orElse: () => rs.first);
      final loot = s.topHits.loot;
      final from = loot.revealFrom ??= rs.indexWhere((x) => x.id == s.fx.raw.obj('cardFx').str('minRarity'));
      final special = source == 'starter';
      s.topHits.loot.card(
        s.clockMs,
        s.topShip - const Offset(0, 52),
        crewId,
        parseArgb(r.color, 'rarities.color'),
        isNew: isNew,
        special: special,
        stars: rs.indexOf(r) + 1,
        reveal: from >= 0 && rs.indexOf(r) >= from,
      );
      if (isNew || special) s.haptic(HapticLevel.medium);
      _sfx(s, isNew || special ? 'crewPromoted' : 'coinArrive', e);
    case GoldOverflow():
      s.topHits.crew.spill(s.clockMs);
    case AttackMissed(:final x, :final y, :final reason):
      s.topHits.crew.miss(x, y, s.clockMs);
      if (reason == 'evade') s.topHits.traits?.bossFx.evade(x, y, s.clockMs);
    case BossTraitFired() when s.isTop:
      s.topHits.traits?.bossFx.fired(e, s.player.tickMs, s.clockMs);
      if (e.trait == 'enrage' || e.trait == 'dash') s.shake.trigger(s.juice.shake['aoe']!);
    case FeverStarted():
      // 화면 흔들기 없음(사용자 '화면이 좌우로 움직이면 조잡하다') — 시작 임팩트는 금빛 번쩍·충격파·'쑥' 가속(세로).
      s.moments.feverFlashMs = s.fx.raw.obj('topEvents').obj('fever').number('flashMs');
      s.haptic(HapticLevel.medium);
      s.topHits.glow.circle(s.clockMs, 90, 0xFFFFC23A); // 개편 ③ 피버 시작 큰 금빛 마법진
      _sfx(s, 'feverStarted', e);
      s.sound.fever(on: true, id: s.fx.raw.obj('topEvents').obj('fever').raw['bgm'] as String?);
    case FeverEnded():
      s.sound.fever(on: false);
    case GoldfishCaught(:final targetId, :final gold):
      final at = s.poseOf(targetId);
      final (x, y) = at == null ? (s.topShip.dx, s.topShip.dy - 30) : (at.drawX, at.drawY);
      s
        ..spawnEffect('coin_burst', x, y)
        ..numbers.add(gold, x, y - 10, DamageKind.crit);
      final (tx, ty) = s.coinTo;
      s.coins.obtain()
        ..fromX = x
        ..fromY = y
        ..toX = tx
        ..toY = ty
        ..spread = 0
        ..lift = 14
        ..fallPx = 0
        ..ageMs = 0
        ..flyMs = s.juice.coinFlyMs
        ..amount = gold
        ..x = x
        ..y = y;
      _sfx(s, 'goldfishCaught', e);
    case BottlePicked():
      final b = s.bottleAt;
      s.spawnEffect('level_up', b.dx, b.dy);
      _sfx(s, 'bottlePicked', e);
    case SeaEventStarted():
      _sfx(s, 'seaEventStarted', e);
    case ShipLookChanged():
      _sfx(s, 'shipLookChanged', e);
    default:
      return false;
  }
  return true;
}

void _sfx(BattleScene s, String key, GameEvent e) => s.sound.sfx(key, clockMs: s.clockMs, tick: e.tick);

/// 지금 보스 자리(없으면 배 앞 90) — 현상금 끝 연출 자리.
Offset _bossAt(BattleScene s) {
  for (var k = 0; k < s.poseCount; k++) {
    final e = s.poses[k];
    if (e.boss) return Offset(e.drawX, e.drawY);
  }
  return s.topShip - const Offset(0, 90);
}
