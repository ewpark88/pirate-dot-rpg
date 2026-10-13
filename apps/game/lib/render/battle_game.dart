import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/game.dart';

/// 전장 논리 해상도 (docs/GAME_DESIGN.md 10장): 320×180, 전장 0~148 / 선원 슬롯 148~180.
const double kLogicalWidth = 320;
const double kLogicalHeight = 180;

/// Flame 전장. 렌더 레인(S3)이 채운다: BattleView를 두 틱 사이로 보간해 그리고,
/// GameEvent를 보고 발사체·이펙트·데미지 숫자·흔들림을 만든다. 명령은 내지 않는다.
class BattleGame extends FlameGame {
  BattleGame()
    : super(
        camera: CameraComponent.withFixedResolution(width: kLogicalWidth, height: kLogicalHeight),
      );

  static const _sea = Color(0xFF1B4F72);

  @override
  Color backgroundColor() => _sea;
}
