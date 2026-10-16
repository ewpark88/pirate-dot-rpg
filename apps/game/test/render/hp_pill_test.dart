import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/paint/hp_pill.dart';

import 'helpers.dart';

/// 체력 막대 색은 딱 끊는 3단계 (사용자 지시 2026-10-16): 40% 이상 초록 · 미만 노랑 · 15% 미만 빨강(빨강만 깜빡임).
void main() {
  final cfg = tables.fxMap.raw.obj('shipHp');
  final pill = HpPill(cfg);
  int c(String k) => int.parse(cfg.str(k).substring(1), radix: 16) | 0xFF000000;

  test('경계 40%·15%', () {
    expect(pill.midBelow, 0.4);
    expect(pill.lowBelow, 0.15);
    expect(pill.colorFor(1), c('full'));
    expect(pill.colorFor(0.40), c('full'));
    expect(pill.colorFor(0.3999), c('mid'));
    expect(pill.colorFor(0.15), c('mid'));
    expect(pill.colorFor(0.1499), c('low'));
    expect(pill.colorFor(0), c('low'));
  });

  test('보간 없음 — 같은 단계 안에서는 같은 색', () {
    expect(pill.colorFor(0.95), pill.colorFor(0.41));
    expect(pill.colorFor(0.39), pill.colorFor(0.16));
  });

  test('깜빡임은 빨강일 때만', () {
    expect(pill.isLow(0.2), isFalse);
    expect(pill.isLow(0.149), isTrue);
  });

  testWidgets('견본 골든', (tester) async {
    tester.view
      ..physicalSize = const Size(480, 690)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(width: 480, height: 690, child: CustomPaint(painter: _Sheet(pill))),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hp_pill.png'));
  });
}

/// 견본: 100·60·40·39·20·15·14·5% (흰 지연 조각 포함) + 해골(보스). 단위 1 = 8px로 키워 찍는다.
class _Sheet extends CustomPainter {
  _Sheet(this.pill);
  final HpPill pill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2E7BC4))
      ..scale(8);
    const ratios = [1.0, 0.6, 0.4, 0.39, 0.2, 0.15, 0.14, 0.05];
    for (var i = 0; i < ratios.length; i++) {
      final r = ratios[i];
      pill.paint(
        canvas,
        left: 2,
        top: 2 + i * 9.0,
        w: 42,
        h: 6,
        ratio: r,
        lag: (r + 0.12).clamp(0, 1),
        fill: pill.colorFor(r),
      );
    }
    pill.paint(
      canvas,
      left: 2,
      top: 2 + 8 * 9.0,
      w: 54,
      h: 6,
      ratio: 0.33,
      lag: 0.4,
      fill: pill.colorFor(0.33),
      skull: true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
