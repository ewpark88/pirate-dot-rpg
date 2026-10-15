import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';

/// 화면 배치 v2 (docs/specs/layout-v2-brief.md): 전장 상자는 화면 폭 전체 × 화면 높이의 약 40% (UI가 정함).
const devices = {
  's24': (Size(384, 832), 2.8125),
  '360x640': (Size(360, 640), 3.0),
  '411x891': (Size(411, 891), 2.625),
};

Size boxOf(Size screen) => Size(screen.width, (screen.height * 0.4).roundToDouble());

void main() {
  for (final MapEntry(key: name, value: (screen, dpr)) in devices.entries) {
    group('battleFrameFor $name', () {
      final box = boxOf(screen);
      final f = battleFrameFor(box, dpr);

      test('폭 기준 정수배, 보이는 영역이 상자를 빈 띠 없이 덮는다', () {
        expect(f.k, (screen.width * dpr / kLogicalWidth).floor());
        expect(f.viewDots.width * f.dot, closeTo(box.width, 1e-6));
        expect(f.viewDots.height * f.dot, closeTo(box.height, 1e-6));
        expect(f.viewDots.left, lessThanOrEqualTo(0));
        expect(f.viewDots.right, greaterThanOrEqualTo(kLogicalWidth));
        // 필드 왼쪽 위가 정수 도트 → 정수 물리 픽셀 (도트가 흐려지지 않는다).
        expect(f.viewDots.left, f.viewDots.left.roundToDouble());
        expect(f.viewDots.top, f.viewDots.top.roundToDouble());
      });

      test('필드는 가로 가운데, 늘어난 높이는 위(하늘)·아래(깊은 바다)로', () {
        final g = f.gameRect;
        expect((g.left - (box.width - g.right)).abs(), lessThanOrEqualTo(2 * f.dot)); // 왼쪽 여백을 정수 도트로 내림
        expect(g.top, greaterThan(0));
        expect(f.bandTop, greaterThanOrEqualTo(kFieldBottom));
      });

      test('선원 줄: 56dp 이상, 상자 맨 아래, 폭 전체', () {
        final b = f.slotBand;
        expect(b.height, greaterThanOrEqualTo(kSlotBandMinDp - 1e-6));
        expect(b.bottom, closeTo(box.height, 1e-6));
        expect(b.width, closeTo(box.width, 1e-6));
      });

      test('궁극기·보스 도전 버튼: 48dp 이상, 상자 안 오른쪽 끝, 슬롯 6칸과 겹치지 않음', () {
        for (final r in [f.ultimateRect, f.bossRect]) {
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.height, greaterThanOrEqualTo(48));
          expect(f.slotBand.contains(r.topLeft) && r.right <= box.width + 1e-6, isTrue);
        }
        expect(f.bossRect.right, lessThanOrEqualTo(f.ultimateRect.left));
        final slots = f.slotRects;
        expect(slots, hasLength(kSlotCount));
        expect(slots.last.right, lessThanOrEqualTo(f.buttonsRect.left));
        for (final s in slots) {
          expect(s.top, greaterThanOrEqualTo(f.slotBand.top));
          expect(s.bottom, lessThanOrEqualTo(f.slotBand.bottom + 1e-6));
        }
      });
    });
  }

  test('기본 배치는 320×180 그대로(골든·테스트용)', () {
    final f = BattleFrame.standard;
    expect(f.viewDots, const Rect.fromLTWH(0, 0, kLogicalWidth, kLogicalHeight));
    expect(f.bandTop, kFieldBottom);
    expect(f.slotRects.last.right, lessThanOrEqualTo(f.ultimateRect.left));
  });

  test('아주 낮은 상자면 정수배를 줄여 필드와 선원 줄이 들어가게', () {
    final f = battleFrameFor(const Size(1200, 260), 1);
    expect(f.k, lessThan(3));
    expect(f.viewDots.height, greaterThanOrEqualTo(kFieldBottom + f.bandDots));
  });
}
