import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/guide/guide_marks.dart';

// 가이드 손가락 자리 (S1 실기기 2026-10-18): 도크(화면 아래 1/4) 대상은 위에서 아래로 가리켜 시스템 내비게이션 바에 안 그린다.

Future<Rect> _finger(WidgetTester tester, Rect at) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1
    ..viewPadding = const FakeViewPadding(bottom: 48);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [GuideFinger(key: const Key('f'), at: at, taps: 0, calm: true)],
      ),
    ),
  );
  return tester.getRect(find.descendant(of: find.byKey(const Key('f')), matching: find.byType(Positioned)).first);
}

void main() {
  testWidgets('도크 아이콘(아래)을 가리키면 손가락은 대상 위쪽', (tester) async {
    const tab = Rect.fromLTWH(300, 700, 50, 46);
    final f = await _finger(tester, tab);
    expect(f.top, lessThan(tab.top));
    expect(f.bottom, lessThanOrEqualTo(800 - 48));
  });

  testWidgets('화면 가운데 대상은 아래쪽(그대로)', (tester) async {
    const mid = Rect.fromLTWH(150, 300, 80, 40);
    final f = await _finger(tester, mid);
    expect(f.top, greaterThan(mid.top));
  });
}
