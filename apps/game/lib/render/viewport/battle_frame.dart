import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/layout.dart';

/// 전장 상자 하나의 배치 (화면 배치 v2 + 사용자 지시 '전장을 키워라'). 렌더 카메라와 UI 버튼이 같은 계산을 쓴다.
///
/// 배율 두 가지:
/// - 필드 [k]: 폭 기준 정수배 + 1 (S24 3 → 4). 320 필드 중 보이는 폭은 약 270 — 왼쪽(배 쪽) 기준, 오른쪽(적 등장 쪽)이 잘린다.
/// - 선원 줄 [kb]: 폭 기준 정수배 그대로 — 슬롯 6칸·궁극기·보스 도전 칸이 폭 전체에 지금 크기로 들어간다.
///
/// 좌표 세 가지:
/// - 도트(dots): 게임 좌표(필드 배율). 320×148 필드가 (0,0)~(320,148). [viewDots]는 상자 전체.
/// - 줄 도트(band): 선원 줄 왼쪽 위가 (0,0), 1칸 = [kb] 물리 픽셀. 그리는 쪽은 [bandOrigin]으로 옮기고 [bandScale]배 한다.
/// - dp: 전장 상자 왼쪽 위가 (0,0)인 논리 픽셀. 1도트 = [dot] dp.
class BattleFrame {
  BattleFrame._({
    required this.k,
    required this.kb,
    required this.dpr,
    required this.viewDots,
    required this.bandTop,
    required this.bandWidth,
    required this.bandHeight,
    this.slotSize = kSlotPlateSize,
    this.slotLeft = kSlotLeft,
    this.slotGap = kSlotStep - 36,
    this.floating = false,
    this.ultimateSide = 0,
    this.bossSide = 0,
  });

  /// 테스트·골든용 기본 배치: 320×180 도트 그대로(필드 0~148, 선원 줄 148~180), 1도트 = 1dp.
  static final standard = BattleFrame._(
    k: 1,
    kb: 1,
    dpr: 1,
    viewDots: const Rect.fromLTWH(0, 0, kLogicalWidth, kLogicalHeight),
    bandTop: kFieldBottom,
    bandWidth: kLogicalWidth,
    bandHeight: kLogicalHeight - kFieldBottom,
  );

  /// 필드·선원 줄의 물리 픽셀 정수배.
  final int k;
  final int kb;
  final double dpr;

  /// 보이는 영역 (도트) = 상자 전체.
  final Rect viewDots;

  /// 선원 줄 윗변 (도트). 물리 픽셀 정수 자리.
  final double bandTop;

  /// 선원 줄 폭·높이 (줄 도트).
  final double bandWidth;
  final double bandHeight;

  /// 칸 크기·왼쪽 여백·칸 사이 (줄 도트). 기본 배치는 예전 도트 칸(36×31, 40 간격), 기기 배치는 정사각 큰 칸(사용자 지시 '초상을 키워라').
  final Size slotSize;
  final double slotLeft;
  final double slotGap;

  /// 궁극기·보스 도전이 줄 밖(전장 오른쪽 아래 구석, 줄 위에 살짝 걸침)에 뜨는가 — 사용자 결정: 줄은 6칸만, 칸을 크게.
  final bool floating;

  /// 뜬 버튼 변 (줄 도트): 궁극기 둥근 큰 버튼, 보스 도전(그 왼쪽).
  final double ultimateSide;
  final double bossSide;

  /// 1도트의 dp 크기.
  double get dot => k / dpr;

  /// 줄 도트 1칸 = 필드 도트 몇 칸.
  double get bandScale => kb / k;

  /// 선원 줄 왼쪽 위 (도트).
  Offset get bandOrigin => Offset(viewDots.left, bandTop);

  /// 선원 줄 높이 (도트) — 이전 이름 호환.
  double get bandDots => viewDots.bottom - bandTop;

  /// 줄 도트 → 도트.
  Offset bandToDots(Offset p) => Offset(viewDots.left + p.dx * bandScale, bandTop + p.dy * bandScale);
  Rect bandRectToDots(Rect r) => Rect.fromPoints(bandToDots(r.topLeft), bandToDots(r.bottomRight));

  /// 칸 [i] (줄 도트).
  Rect slotRectInBand(int i) => Rect.fromLTWH(
    slotLeft + i * (slotSize.width + slotGap),
    ((bandHeight - slotSize.height) / 2).floorToDouble(),
    slotSize.width,
    slotSize.height,
  );

  /// 칸 [i] 왼쪽 위 (줄 도트) — 이전 이름.
  Offset slotInBand(int i) => slotRectInBand(i).topLeft;

  /// 버튼 한 칸 변 (줄 도트, 정사각, 예전 배치): 띠 높이에서 위아래 3칸씩, 슬롯 6칸 뒤 남는 폭이 모자라면 줄인다.
  double get _button {
    final room = (bandWidth - kSlotLeft - kSlotCount * kSlotStep - kButtonGap * 3) / 2;
    return math.max(kButtonMinDots, math.min(bandHeight - kButtonGap * 2, room)).floorToDouble();
  }

  /// 궁극기 버튼 (줄 도트). 예전 배치: 줄 오른쪽 끝. 뜬 배치: 오른쪽 끝 칸 위, 아랫변 = 칸 윗변(줄 위 여백에 살짝 걸침, y < 0).
  /// 렌더가 그리고 UI가 투명 버튼을 얹는다.
  Rect get ultimateInBand {
    if (floating) {
      final d = ultimateSide;
      return Rect.fromLTWH((bandWidth - slotLeft - d).floorToDouble(), slotRectInBand(0).top - d, d, d);
    }
    final b = _button;
    return Rect.fromLTWH((bandWidth - kButtonGap - b).floorToDouble(), ((bandHeight - b) / 2).floorToDouble(), b, b);
  }

  /// 보스 도전 버튼 자리 (줄 도트): 궁극기 왼쪽(뜬 배치는 세로 가운데 맞춤). 렌더는 비워 두고 UI가 그린다.
  Rect get bossInBand {
    final u = ultimateInBand;
    if (floating) {
      final b = bossSide;
      return Rect.fromLTWH(u.left - slotGap * 2 - b, (u.center.dy - b / 2).floorToDouble(), b, b);
    }
    return u.shift(Offset(-(_button + kButtonGap), 0));
  }

  /// 같은 자리를 도트로 (테스트·픽셀 확인용).
  Offset slotAt(int i) => bandToDots(slotInBand(i));
  Rect get ultimateDots => bandRectToDots(ultimateInBand);
  Rect get bossDots => bandRectToDots(bossInBand);

  /// 보이는 오른쪽 끝 (도트) — 필드를 키우면 320보다 작다(오른쪽이 잘림).
  double get visibleRight => math.min(kLogicalWidth, viewDots.right);

  /// 보스는 등장 자리(엔진 x 300)가 잘린 화면 밖이어도 보이는 오른쪽 끝 안에 그린다(보스 발사체·숫자도 같은 x).
  double clampBossX(double x) => math.min(x, visibleRight - kBossEdgeInset);

  /// 도트 → dp (전장 상자 기준).
  Offset toDp(Offset dots) => Offset((dots.dx - viewDots.left) * dot, (dots.dy - viewDots.top) * dot);

  Rect rectToDp(Rect dots) => Rect.fromPoints(toDp(dots.topLeft), toDp(dots.bottomRight));

  /// 320×148 필드가 그려지는 dp 사각형 (보물상자 탭 좌표 등). 오른쪽 끝은 상자 밖으로 나갈 수 있다.
  Rect get gameRect => rectToDp(const Rect.fromLTWH(0, 0, kLogicalWidth, kFieldBottom));

  /// 선원 줄 (dp, 상자 폭 전체).
  Rect get slotBand => rectToDp(Rect.fromLTRB(viewDots.left, bandTop, viewDots.right, viewDots.bottom));

  /// 슬롯 6칸 (dp).
  List<Rect> get slotRects => [
    for (var i = 0; i < kSlotCount; i++) rectToDp(bandRectToDots(slotRectInBand(i))),
  ];

  Rect get ultimateRect => rectToDp(ultimateDots);
  Rect get bossRect => rectToDp(bossDots);

  /// 궁극기·보스 도전 두 칸을 합친 영역 (dp).
  Rect get buttonsRect => bossRect.expandToInclude(ultimateRect);
}

/// 전장 상자 [box](dp)를 빈 띠 없이 채우는 배치.
/// - 필드 배율 k = floor(폭·dpr / 320) + [boost] (사용자 지시 '전장을 키워라' — 기본 +1). 줄 배율 kb = floor(폭·dpr / 320),
///   단 1줄 도트 ≤ [kBandDotMaxDp] dp (태블릿에서 슬롯·버튼 상한).
///   필드 148 + 선원 줄이 상자 높이에 안 들어가면 k를 줄인다(kb ≤ k).
/// - 선원 줄 높이 = max(32줄 도트, 56dp). 줄 윗변은 정수 물리 픽셀.
/// - 필드 가로: 보이는 폭 < 320이면 왼쪽(배 쪽) 기준, 넓으면 가운데. 남는 높이는 위 70% 하늘, 아래 30% 깊은 바다.
BattleFrame battleFrameFor(Size box, double dpr, {int boost = 1}) {
  final physW = box.width * dpr;
  final physH = box.height * dpr;
  // 태블릿처럼 넓으면 줄 배율을 1줄 도트 ≤ kBandDotMaxDp dp로 묶는다(슬롯·버튼이 과하게 커지지 않게).
  var kb = math.max(1, math.min((physW / kLogicalWidth).floor(), (kBandDotMaxDp * dpr).floor()));
  final base = math.max(1, (physW / kLogicalWidth).floor());
  // 칸(사용자 결정 '6칸을 키워라'): 6칸이 한 줄에 들어가는 가장 큰 정사각, 최대 kSlotMaxDp. 궁극기는 줄 밖.
  final sideDp = math.min(kSlotMaxDp, (box.width - 2 * kSlotEdgeDp - (kSlotCount - 1) * kSlotGapDp) / kSlotCount);
  double band(int kb) => math.max(
    math.max(kSlotBandMinDots, (kSlotBandMinDp * dpr / kb).ceilToDouble()),
    ((sideDp + 2 * kSlotPadDp) * dpr / kb).ceilToDouble(),
  );
  var k = base + boost;
  while (k > 1 && (physH - band(math.min(kb, k)) * math.min(kb, k)) / k < kFieldBottom) {
    k--;
  }
  kb = math.min(kb, k);
  final bandDot = kb / dpr;
  final side = (sideDp / bandDot).floorToDouble();
  final bandH = band(kb);
  final bandPhysTop = (physH - bandH * kb).floorToDouble();
  final w = physW / k;
  final h = physH / k;
  final fieldH = bandPhysTop / k;
  final extra = math.max<double>(0, fieldH - kFieldBottom);
  final left = w >= kLogicalWidth ? ((w - kLogicalWidth) / 2).floorToDouble() : 0.0;
  final top = (extra * kSkyShare).floorToDouble();
  return BattleFrame._(
    k: k,
    kb: kb,
    dpr: dpr,
    viewDots: Rect.fromLTWH(-left, -top, w, h),
    bandTop: -top + bandPhysTop / k,
    bandWidth: physW / kb,
    bandHeight: (physH - bandPhysTop) / kb,
    slotSize: Size(side, side),
    // 칸이 상한(72dp)에 걸려 폭이 남으면(태블릿) 6칸을 가운데로.
    slotLeft:
        math.max(kSlotEdgeDp, (box.width - kSlotCount * sideDp - (kSlotCount - 1) * kSlotGapDp) / 2) ~/ bandDot * 1.0,
    slotGap: (kSlotGapDp / bandDot).floorToDouble(),
    floating: true,
    ultimateSide: (sideDp.clamp(kUltimateMinDp, kUltimateMaxDp) / bandDot).floorToDouble(),
    bossSide: (kBossButtonDp / bandDot).ceilToDouble(),
  );
}
