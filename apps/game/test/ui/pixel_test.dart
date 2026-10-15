import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';

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

  testWidgets('기준 2: 프레임 바깥 윤곽이 칸 단위(테두리 두께 = 칸의 정수배)', (tester) async {
    await _pump(
      tester,
      const SizedBox(width: 80, height: 40, child: PixelFrame(child: SizedBox.expand())),
      dpr: 2,
      size: const Size(320, 200),
    );
    final painter = tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter! as PixelFramePainter;
    expect(painter.unit * 2, 2); // 물리 640 → k=2 → 1칸 = 1dp = 2px
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

  testWidgets('도트 버튼: 누르는 동안 1칸 내려간다', (tester) async {
    await _pump(tester, PixelButton(onPressed: () {}, child: const Text('OK')));
    final before = tester.getTopLeft(find.byType(PixelFrame));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PixelButton)));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(PixelFrame)).dy, before.dy + 1);
    await gesture.up();
    await tester.pump();
    expect(tester.getTopLeft(find.byType(PixelFrame)), before);
  });

  test('팔레트는 기준 scene3.py 값', () {
    expect(PixelPalette.outline, const Color.fromARGB(255, 27, 23, 38));
    expect(PixelPalette.gold, const Color.fromARGB(255, 242, 201, 76));
    expect(PixelPalette.slot, const Color.fromARGB(255, 150, 176, 214));
  });
}
