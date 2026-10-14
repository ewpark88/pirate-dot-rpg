import 'package:flutter/foundation.dart';

/// 설정 화면의 접근성·저사양 옵션 (docs/GAME_DESIGN.md 4.4). 렌더는 값만 받고, 연결은 UI 레인이 한다.
@immutable
class JuiceSettings {
  const JuiceSettings({this.shake = true, this.flash = true, this.vibration = true, this.powerSave = false});

  final bool shake;
  final bool flash;
  final bool vibration;

  /// 절전 모드: juice.json powerSave.fps로 그린다.
  final bool powerSave;

  JuiceSettings copyWith({bool? shake, bool? flash, bool? vibration, bool? powerSave}) => JuiceSettings(
    shake: shake ?? this.shake,
    flash: flash ?? this.flash,
    vibration: vibration ?? this.vibration,
    powerSave: powerSave ?? this.powerSave,
  );
}

/// 진동 세기 (juice.json vibration 값).
enum HapticLevel { light, medium }
