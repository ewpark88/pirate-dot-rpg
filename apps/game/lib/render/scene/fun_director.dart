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
    case FeverStarted():
      s.moments.feverFlashMs = s.fx.raw.obj('topEvents').obj('fever').number('flashMs');
      s.shake.trigger(s.juice.shake['aoe']!);
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
