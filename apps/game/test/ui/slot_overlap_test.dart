import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';

import 'ui_harness.dart';

// 사용자 버그 (2026-10-15): "슬롯 창(선원 줄)이 하단 메뉴에 가려질 때가 한 번씩 있다."
// 4기기 × (도크 닫힘 / 시트 50% / 90% / 끌기 중간 / 빠르게 열고 닫기의 모든 프레임)에서
// 선원 줄 칸·궁극기 사각형이 도크·시트 사각형과 겹치지 않음을 단언한다.

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('S24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

/// 선원 줄 칸·궁극기(화면 좌표)의 가장 낮은 아랫변.
double _slotBottom(WidgetTester tester, double dpr) {
  final area = tester.getRect(find.byKey(const Key('battle.area')));
  final f = battleFrameFor(area.size, dpr);
  final rects = [...f.slotRects, f.ultimateRect].map((r) => r.shift(area.topLeft));
  return rects.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
}

/// 아래에서 가리는 것의 가장 높은 윗변: 시트(열림) 또는 도크(닫힘)·도크 위 띠.
double _coverTop(WidgetTester tester) {
  final tops = <double>[];
  for (final key in ['sheet.panel', 'dock.bottom']) {
    final f = find.byKey(Key(key));
    if (f.evaluate().isNotEmpty) tops.add(tester.getRect(f).top);
  }
  return tops.reduce((a, b) => a < b ? a : b);
}

void _check(WidgetTester tester, double dpr, String what) {
  final slot = _slotBottom(tester, dpr);
  final cover = _coverTop(tester);
  expect(slot, lessThanOrEqualTo(cover + 0.5), reason: '$what: 선원 줄 아래 $slot > 가림 위 $cover');
}

void main() {
  for (final (name, size, dpr) in _devices) {
    testWidgets('$name: 닫힘·50%·90%·끌기 중간·빠른 열고 닫기 — 선원 줄이 가려지지 않는다', (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), size: size, dpr: dpr, openTab: false);
      _check(tester, dpr, '닫힘');

      // 열기: 애니메이션 모든 프레임.
      await tester.tap(find.byKey(const Key('tab.1')));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        _check(tester, dpr, '여는 중 $i');
      }
      await tester.pumpAndSettle();
      _check(tester, dpr, '50%');

      // 끌기 중간 (놓기 전) → 90%.
      final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('sheet.handle'))));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(Offset(0, -size.height * 0.05));
        await tester.pump();
        _check(tester, dpr, '끄는 중 $i');
      }
      await g.up();
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        _check(tester, dpr, '놓은 뒤 $i');
      }
      await tester.pumpAndSettle();
      _check(tester, dpr, '끝까지');

      // 빠르게 닫고 다시 열고 닫기.
      for (final tab in [1, 2, 2]) {
        await tester.tap(find.byKey(Key('tab.$tab')), warnIfMissed: false);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          _check(tester, dpr, '빠른 전환 $tab-$i');
        }
      }
      await tester.pumpAndSettle();
      _check(tester, dpr, '마지막');
    });
  }
}
