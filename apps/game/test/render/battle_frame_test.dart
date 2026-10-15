import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';

/// 화면 배치 v2 + 사용자 지시 '전장을 키워라': 전장 상자는 화면 폭 전체 × 화면 높이의 약 45% (UI가 정함), 필드 도트 배율 +1.
const devices = {
  's24': (Size(384, 832), 2.8125),
  '360x640': (Size(360, 640), 3.0),
  '411x891': (Size(411, 891), 2.625),
  'tablet800x1280': (Size(800, 1280), 2.0),
};

Size boxOf(Size screen) => Size(screen.width, (screen.height * 0.45).roundToDouble());

void main() {
  for (final MapEntry(key: name, value: (screen, dpr)) in devices.entries) {
    group('battleFrameFor $name', () {
      final box = boxOf(screen);
      final f = battleFrameFor(box, dpr);

      test('필드는 폭 기준 정수배 + 1, 선원 줄은 폭 기준 정수배 — 보이는 영역이 상자를 빈 띠 없이 덮는다', () {
        final base = (screen.width * dpr / kLogicalWidth).floor();
        expect(f.kb, math.min(base, (kBandDotMaxDp * dpr).floor()));
        expect(f.k, base + 1);
        expect(f.viewDots.width * f.dot, closeTo(box.width, 1e-6));
        expect(f.viewDots.height * f.dot, closeTo(box.height, 1e-6));
        // 필드·줄 윗변이 정수 물리 픽셀 → 도트가 흐려지지 않는다.
        expect(f.viewDots.left, f.viewDots.left.roundToDouble());
        expect(f.viewDots.top, f.viewDots.top.roundToDouble());
        final bandPhys = (f.bandTop - f.viewDots.top) * f.k;
        expect(bandPhys, closeTo(bandPhys.roundToDouble(), 1e-6));
      });

      test('필드는 왼쪽(배 쪽) 기준, 보이는 폭은 약 270 — 오른쪽(적 등장 쪽)이 잘린다', () {
        expect(f.viewDots.left, 0);
        expect(f.viewDots.right, inInclusiveRange(250, 300));
        expect(f.gameRect.left, 0);
        expect(f.gameRect.right, greaterThan(box.width));
        expect(f.bandTop - kFieldBottom, greaterThanOrEqualTo(0), reason: '필드 148이 선원 줄 위에 다 들어간다');
      });

      test('선원 줄: 56dp 이상(칸 + 위아래 여백), 상자 맨 아래, 폭 전체', () {
        final b = f.slotBand;
        expect(b.height, greaterThanOrEqualTo(kSlotBandMinDp - 1e-6));
        expect(b.bottom, closeTo(box.height, 1 / dpr + 1e-6), reason: '줄 윗변이 정수 물리 픽셀 — 1px 안');
        expect(b.width, closeTo(box.width, 1e-6));
      });

      test('도크·시트(bottomInset): 줄은 가려지지 않는 맨 아래로, 배율은 그대로, 배는 보인다', () {
        // 전체 화면 상자 = 화면(지금 상자는 화면의 45%) − 상단 바 48dp. 닫힘 = 도크 72dp, 열림 = 화면 아래 50%.
        final full = Size(box.width, box.height / 0.45 - 48);
        final closed = battleFrameFor(full, dpr, bottomInset: 72);
        for (final inset in [72.0, full.height * 0.5 + 24]) {
          final g = battleFrameFor(full, dpr, bottomInset: inset);
          expect(g.k, closed.k, reason: '시트를 끌어도 그림 크기는 그대로');
          expect(g.slotBand.bottom, closeTo(full.height - inset, 1 / dpr + 1e-6));
          expect(g.slotRects.first.width, closeTo(closed.slotRects.first.width, 1e-6));
          final shipBottomDp = g.toDp(const Offset(0, kShipTop + kShipHeight)).dy;
          final shipTopDp = g.toDp(const Offset(0, kShipTop)).dy;
          expect(shipTopDp, greaterThanOrEqualTo(-1e-6), reason: '배 윗부분이 상자 안 ($inset)');
          expect(shipBottomDp, lessThanOrEqualTo(g.slotBand.top + 1e-6), reason: '배가 선원 줄 위 ($inset)');
        }
      });

      test('선원 줄 도트 상한: 슬롯 판 ≤ 58dp (태블릿에서 과하게 커지지 않음)', () {
        expect(f.bandScale * f.dot, lessThanOrEqualTo(kBandDotMaxDp + 1e-9));
        expect(f.slotRects.first.width, lessThanOrEqualTo(kSlotMaxDp + 1e-6));
      });

      test('큰 칸(사용자 결정): 6칸이 한 줄, 칸 46~72dp / 궁극기 둥근 버튼은 오른쪽 끝 칸 위(전장 구석, 줄 위 여백에 걸침), 보스 도전은 그 왼쪽', () {
        final slots = f.slotRects;
        expect(slots, hasLength(kSlotCount));
        for (final s in slots) {
          expect(s.width, inInclusiveRange(46, kSlotMaxDp + 1e-6));
          expect(s.top, greaterThanOrEqualTo(f.slotBand.top));
          expect(s.bottom, lessThanOrEqualTo(f.slotBand.bottom + 1e-6));
        }
        expect(slots.last.right, lessThanOrEqualTo(box.width + 1e-6));
        final u = f.ultimateRect;
        expect(u.width, inInclusiveRange(kUltimateMinDp - 2, kUltimateMaxDp + 1e-6));
        expect(u.right, lessThanOrEqualTo(box.width + 1e-6));
        expect(u.bottom, lessThanOrEqualTo(slots.last.top + 1e-6), reason: '칸을 가리지 않는다');
        expect(u.bottom, greaterThan(f.slotBand.top), reason: '줄 위 여백에 살짝 걸친다');
        final b = f.bossRect;
        expect(b.width, greaterThanOrEqualTo(kBossButtonDp - 1e-6));
        expect(b.right, lessThanOrEqualTo(u.left));
        expect(b.bottom, lessThanOrEqualTo(slots.last.top + 1e-6));
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
    expect(f.bandTop, greaterThanOrEqualTo(kFieldBottom));
  });
}
