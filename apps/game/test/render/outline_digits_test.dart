import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/text/outline_digits.dart';

/// 테두리 숫자 아틀라스(디자인 개편 공용 부품): 표·폭 계산·그림 읽기·그리기.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final layout = OutlineDigitsLayout.fromJson(
    jsonDecode(File('$outlineDigitsAsset.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('표: 숫자 0~9·K·M·B·T·%·/·+·×·.·,·-·: 와 4색 줄', () {
    for (final ch in '0123456789KMBT%/+×.,-:'.split('')) {
      expect(layout.glyphs, contains(ch), reason: ch);
    }
    expect(layout.rows.keys, ['white', 'gold', 'red', 'green']);
  });

  test('폭: 글자가 늘면 넓어지고, 없는 글자는 0, 공백은 반 칸보다 작게, 높이에 비례', () {
    final one = layout.measure('1');
    expect(layout.measure('12.5K'), greaterThan(layout.measure('12')));
    expect(layout.measure('1?'), one);
    expect(layout.measure('1 1'), lessThan(layout.measure('1') * 2 + layout.cellHeight * 0.5));
    expect(layout.measure('1', height: layout.cellHeight * 2), closeTo(one * 2, 1e-9));
  });

  testWidgets('읽기: 기기 배율 3이면 3.0x 그림(배율 3), 그리면 그린 폭을 돌려준다', (tester) async {
    final d = await tester.runAsync(() => OutlineDigits.load(bundle: rootBundle, devicePixelRatio: 3));
    expect(d!.scale, closeTo(3, 1e-9));
    final rec = ui.PictureRecorder();
    final w = d.paint(ui.Canvas(rec), Offset.zero, '1.2K', color: 'gold', height: 20);
    rec.endRecording();
    expect(w, closeTo(layout.measure('1.2K', height: 20), 1e-9));
  });
}
