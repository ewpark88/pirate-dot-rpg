import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/layout.dart';

/// 전장 상자 하나의 배치 (화면 배치 v2, docs/specs/layout-v2-brief.md). 렌더 카메라와 UI 버튼이 같은 계산을 쓴다.
///
/// 좌표 두 가지:
/// - 도트(dots): 게임 좌표. 320×148 필드가 (0,0)~(320,148). 상자가 넓거나 높으면 [viewDots]가 그 바깥(음수·320 넘음)까지 넓어진다.
/// - dp: 전장 상자 왼쪽 위가 (0,0)인 논리 픽셀. 1도트 = [dot] dp (= k / dpr).
class BattleFrame {
  BattleFrame._({required this.k, required this.dot, required this.viewDots, required this.bandDots});

  /// 테스트·골든용 기본 배치: 320×180 도트 그대로(필드 0~148, 선원 줄 148~180), 1도트 = 1dp.
  static final standard = BattleFrame._(
    k: 1,
    dot: 1,
    viewDots: const Rect.fromLTWH(0, 0, kLogicalWidth, kLogicalHeight),
    bandDots: kLogicalHeight - kFieldBottom,
  );

  /// 물리 픽셀 정수배.
  final int k;

  /// 1도트의 dp 크기.
  final double dot;

  /// 보이는 영역 (도트). 필드는 가로 가운데, 남는 위는 하늘·아래는 깊은 바다, 맨 아래 [bandDots]는 선원 줄.
  final Rect viewDots;

  /// 선원 줄 높이 (도트).
  final double bandDots;

  /// 선원 줄 윗변 (도트).
  double get bandTop => viewDots.bottom - bandDots;

  /// 슬롯 판 왼쪽 위 (도트). 판 크기는 [kSlotPlateSize].
  Offset slotAt(int i) => Offset(
    viewDots.left + kSlotLeft + i * kSlotStep,
    (bandTop + (bandDots - kSlotPlateSize.height) / 2).floorToDouble(),
  );

  /// 버튼 한 칸 변 (도트, 정사각). 띠 높이에서 위아래 3도트씩, 슬롯 6칸 뒤 남는 폭이 모자라면 줄인다.
  double get _button {
    final room = (viewDots.width - kSlotLeft - kSlotCount * kSlotStep - kButtonGap * 3) / 2;
    return math.max(kButtonMinDots, math.min(bandDots - kButtonGap * 2, room)).floorToDouble();
  }

  /// 궁극기 버튼 (도트): 선원 줄 오른쪽 끝. 렌더가 테두리·선장 초상·함성 게이지를 그리고, UI가 투명 버튼을 얹는다.
  Rect get ultimateDots {
    final b = _button;
    return Rect.fromLTWH(
      (viewDots.right - kButtonGap - b).floorToDouble(),
      (bandTop + (bandDots - b) / 2).floorToDouble(),
      b,
      b,
    );
  }

  /// 보스 도전 버튼 자리 (도트): 궁극기 왼쪽. 렌더는 비워 두고 UI가 그린다.
  Rect get bossDots => ultimateDots.shift(Offset(-(_button + kButtonGap), 0));

  /// 도트 → dp (전장 상자 기준).
  Offset toDp(Offset dots) => Offset((dots.dx - viewDots.left) * dot, (dots.dy - viewDots.top) * dot);

  Rect rectToDp(Rect dots) => Rect.fromPoints(toDp(dots.topLeft), toDp(dots.bottomRight));

  /// 320×148 필드가 그려지는 dp 사각형 (보물상자 탭 좌표 등).
  Rect get gameRect => rectToDp(const Rect.fromLTWH(0, 0, kLogicalWidth, kFieldBottom));

  /// 선원 줄 (dp, 상자 폭 전체).
  Rect get slotBand => rectToDp(Rect.fromLTRB(viewDots.left, bandTop, viewDots.right, viewDots.bottom));

  /// 슬롯 6칸 (dp).
  List<Rect> get slotRects => [
    for (var i = 0; i < kSlotCount; i++) rectToDp(slotAt(i) & kSlotPlateSize),
  ];

  Rect get ultimateRect => rectToDp(ultimateDots);
  Rect get bossRect => rectToDp(bossDots);

  /// 궁극기·보스 도전 두 칸을 합친 영역 (dp).
  Rect get buttonsRect => bossRect.expandToInclude(ultimateRect);
}

/// 전장 상자 [box](dp)를 빈 띠 없이 채우는 배치 (화면 배치 v2 규칙).
/// - k = 폭 기준 정수배 floor(폭·dpr / 320), 필드 148 + 선원 줄이 높이에 안 들어가면 줄인다(최소 1).
/// - 선원 줄 높이 = max(32도트, 56dp).
/// - 남는 높이는 위 70% 하늘, 아래 30% 깊은 바다. 필드 왼쪽 위는 정수 도트 → 정수 물리 픽셀에 놓인다.
BattleFrame battleFrameFor(Size box, double dpr) {
  double band(int k) => math.max(kSlotBandMinDots, (kSlotBandMinDp * dpr / k).ceilToDouble());
  var k = math.max(1, (box.width * dpr / kLogicalWidth).floor());
  while (k > 1 && box.height * dpr / k < kFieldBottom + band(k)) {
    k--;
  }
  final b = band(k);
  final w = box.width * dpr / k;
  final h = box.height * dpr / k;
  final extra = math.max<double>(0, h - kFieldBottom - b);
  final left = ((w - kLogicalWidth) / 2).floorToDouble();
  final top = (extra * kSkyShare).floorToDouble();
  return BattleFrame._(k: k, dot: k / dpr, viewDots: Rect.fromLTWH(-left, -top, w, h), bandDots: b);
}
