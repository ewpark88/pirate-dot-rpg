import 'dart:ui';

import 'package:game_core/game_core.dart';
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
    case GoldOverflow():
      s.topHits.crew.spill(s.clockMs);
    case AttackMissed(:final x, :final y):
      s.topHits.crew.miss(x, y, s.clockMs);
    case FeverStarted():
      // 화면 흔들기 없음(사용자 '화면이 좌우로 움직이면 조잡하다') — 시작 임팩트는 금빛 번쩍·충격파·'쑥' 가속(세로).
      s.moments.feverFlashMs = s.fx.raw.obj('topEvents').obj('fever').number('flashMs');
      s.haptic(HapticLevel.medium);
      _sfx(s, 'feverStarted', e);
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
