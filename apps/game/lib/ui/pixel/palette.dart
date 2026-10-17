import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// UI 색 이름표 — 스킨 r1(파스텔, ui/skin/skin.dart)로 다시 칠했다. 이름은 예전 도트 시절 그대로 두어 화면 코드가 한 번에 바뀐다.
/// 새 코드는 `Skin`을 직접 쓴다.
abstract final class PixelPalette {
  /// 판(카드·창) 바탕 — 흰색.
  static const Color navy = Skin.card;

  /// 판 테두리·구분선 — 옅은 하늘 회색.
  static const border = Color(0xFF8E90C8);

  /// 하이라이트(흰).
  static const highlight = Color(0xFFFFFFFF);

  /// 작은 띠·칩 바탕 — 아주 옅은 하늘.
  static const outline = Color(0xFFE6E5FF);

  /// 눌린·비활성 바탕.
  static const Color navyPressed = Skin.plainBottom;

  /// 글자 — 잉크 남색.
  static const Color text = Skin.ink;

  /// 흐린 글자.
  static const Color textDim = Skin.sub;

  /// 골드 숫자(흰 바탕에서 읽히게 진하게).
  static const gold = Color(0xFF7A4A00);

  /// 위험·빨간 점.
  static const Color danger = Skin.danger;

  /// 강조.
  static const accent = Color(0xFF8E3A00);

  /// 선원 슬롯 바탕.
  static const slot = Color(0xFFC6C7EF);

  /// 주 버튼 바탕.
  static const Color action = Skin.primaryBottom;

  /// 주 버튼 밝은 쪽.
  static const Color actionLight = Skin.primaryTop;

  /// 주 버튼 진한 쪽.
  static const Color actionDark = Skin.primaryEdge;

  /// 막대 바탕(상단 바·탭 바 아래 판).
  static const navyDark = Color(0xFFE9E7FC);
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
