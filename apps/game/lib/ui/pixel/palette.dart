import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 도트 팔레트 (기준: 이미지참고용 전투 v0.3 scene3.py, 스펙 ui-quality-v1). UI의 색은 모두 여기서.
abstract final class PixelPalette {
  /// 패널 바탕 남색.
  static const navy = Color.fromARGB(255, 24, 30, 52);

  /// 패널 테두리.
  static const border = Color.fromARGB(255, 60, 70, 110);

  /// 테두리 안쪽 하이라이트 (위·왼쪽 1px).
  static const highlight = Color.fromARGB(255, 92, 104, 150);

  /// 도트 윤곽선 (글자·아이콘 바깥 1px).
  static const outline = Color.fromARGB(255, 27, 23, 38);

  /// 눌린 버튼 바탕.
  static const navyPressed = Color.fromARGB(255, 16, 20, 36);

  /// 글자.
  static const text = Color.fromARGB(255, 255, 255, 255);

  /// 흐린 글자 (비활성·부가 설명).
  static const textDim = Color.fromARGB(255, 150, 160, 190);

  /// 골드 숫자.
  static const gold = Color.fromARGB(255, 242, 201, 76);

  /// 함성 막대·위험·빨간 점.
  static const danger = Color.fromARGB(255, 255, 90, 90);

  /// 콤보·강조.
  static const accent = Color.fromARGB(255, 255, 210, 63);

  /// 선원 슬롯 바탕.
  static const slot = Color.fromARGB(255, 150, 176, 214);

  /// 주 버튼 바탕(강화·소환 등 누르면 이득인 버튼).
  static const action = Color.fromARGB(255, 46, 120, 190);

  /// 주 버튼 테두리.
  static const actionBorder = Color.fromARGB(255, 110, 180, 240);
}

/// 기준 화면의 논리 폭 (320×180, 기기에 맞춰 정수배 확대).
const _artWidth = 320;

/// 도트 한 칸의 크기(dp). 실제 화면 픽셀 기준으로 정수배(k = floor(물리 폭 / 320), 최소 1)라 테두리가 번지지 않는다.
double pixelUnit(BuildContext context) {
  final mq = MediaQuery.of(context);
  return pixelUnitFor(mq.size.width, mq.devicePixelRatio);
}

/// [pixelUnit]의 계산 (테스트용으로 분리).
double pixelUnitFor(double logicalWidth, double devicePixelRatio) {
  final k = math.max(1, (logicalWidth * devicePixelRatio / _artWidth).floor());
  return k / devicePixelRatio;
}
