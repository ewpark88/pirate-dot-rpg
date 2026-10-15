import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double dpr = 1, Size size = const Size(400, 300)}) async {
  tester.view
    ..physicalSize = size * dpr
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('기준 1: 도트 한 칸 = 실제 화면 픽셀의 정수배 (320 기준)', () {
    for (final (width, dpr, k) in [
      (360.0, 1.0, 1),
      (640.0, 1.0, 2),
      (360.0, 3.0, 3),
      (412.0, 2.625, 3),
      (300.0, 1.0, 1),
    ]) {
      test('폭 $width × dpr $dpr → k=$k', () {
        final u = pixelUnitFor(width, dpr);
        expect(u * dpr, k); // 실제 픽셀로는 정수
      });
    }
  });

  testWidgets('도트 버튼: 누르면 콜백, 최소 48dp, 비활성은 콜백 없음', (tester) async {
    var taps = 0;
    await _pump(tester, PixelButton(onPressed: () => taps++, child: const Text('OK')));
    expect(tester.getSize(find.byType(PixelButton)).height, greaterThanOrEqualTo(kMinTap));
    await tester.tap(find.byType(PixelButton));
    expect(taps, 1);

    await _pump(tester, const PixelButton(onPressed: null, child: Text('OK')));
    await tester.tap(find.byType(PixelButton));
    expect(taps, 1);
  });

  testWidgets('스킨 버튼: 누르는 동안 내려앉았다가 놓으면 돌아온다', (tester) async {
    await _pump(tester, PixelButton(onPressed: () {}, child: const Text('OK')));
    Finder face() => find.descendant(of: find.byType(PixelButton), matching: find.text('OK'));
    final before = tester.getTopLeft(face());
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PixelButton)));
    // 탭 시작은 제스처 판정(약 100ms) 뒤에 온다.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(face()).dy, greaterThan(before.dy));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(face()).dy, closeTo(before.dy, 0.01));
  });

  test('팔레트는 스킨 r1 값 (docs/specs/ui-skin-r1.md)', () {
    expect(Skin.sky, const Color(0xFFDDF2FF));
    expect(Skin.primaryBottom, const Color(0xFF1460C4));
    expect(Skin.goldBottom, const Color(0xFFFFB31F));
    expect(PixelPalette.text, Skin.ink);
  });
}
