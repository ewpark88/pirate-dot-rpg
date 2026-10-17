import 'package:flutter_riverpod/flutter_riverpod.dart';

// HUD 배치 안 (사용자 2026-10-17 '상태바와 메뉴바 위치를 더 좋은 곳으로 — 가능한지 검토'): 지금 배치와 대안 3개를
// 같은 앱에서 바꿔 볼 수 있게(운영자 패널 · 시안 골든). 사용자가 고르면 그 하나만 남긴다.

enum HudLayout {
  /// 지금: 위 막대 · 위 진행 게이지(남색 판) · 아래 도크 76dp.
  now,

  /// 엄지: 진행 게이지를 아래 도크 위로(엄지 닿는 곳) — 위쪽 전장이 넓어진다.
  thumb,

  /// 떠 있는 띠: 진행 게이지 판을 없애고 전장 위에 글자·막대만(외곽선) — 전장을 덜 가린다.
  floating,

  /// 얇은 도크: 도크 58dp, 고른 탭만 이름 — 전장이 아래로 넓어진다.
  slim,
}

final hudLayoutProvider = NotifierProvider<HudLayoutNotifier, HudLayout>(HudLayoutNotifier.new);

class HudLayoutNotifier extends Notifier<HudLayout> {
  @override
  HudLayout build() => HudLayout.now;

  // 운영자 패널이 고른다.
  // ignore: use_setters_to_change_properties
  void pick(HudLayout layout) => state = layout;
}

/// 엄지 배치에서 도크 위에 얹는 진행 게이지 자리(dp).
const double thumbGaugeHeight = 62;

/// 도크 높이(dp): 기본 76 · 엄지는 게이지 자리를 더함 · 얇은 도크 58.
double dockHeightFor(HudLayout l) => switch (l) {
  HudLayout.thumb => 76 + thumbGaugeHeight,
  HudLayout.slim => 58,
  _ => 76,
};
