import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/paint/combo_banner.dart';
import 'package:pirate_dot/render/scene/scene_state.dart';

/// 콤보 v2 (피드백 #4 핵앤슬래시): 처치가 1초 안에 이어지면 연쇄가 쌓이고, 끊기면 0부터.
/// 배너는 연쇄가 길수록 크고 뜨겁게, 10·25·50·100에서 터진다.
void main() {
  test('연쇄: 1초 안에 이어지면 쌓이고, 끊기면 다시 1, 1.5초 뒤 화면에서 사라진다', () {
    final c = ComboTracker(windowMs: 1000);
    for (var i = 0; i < 12; i++) {
      c.add(i * 400.0);
    }
    expect(c.count(4400), 12);
    expect(c.count(4400 + 1600), 0, reason: '끊긴 지 1.5초 넘으면 안 보임');
    c.add(7000);
    expect(c.count(7000), 1, reason: '끊긴 뒤 처치는 1부터');
  });

  test('단계 넘김(10·25·50·100)마다 한 번씩 터진다', () {
    final b = ComboBanner();
    final hit = <int>[];
    final canvas = Canvas(PictureRecorder());
    for (var n = 1; n <= 120; n++) {
      b.paint(canvas, 100, 20, n, n * 100.0, n * 100.0, minKills: 5, baseColor: 0xFFFFD23F, onMilestone: hit.add);
    }
    expect(hit, [10, 25, 50, 100]);
    expect(ComboBanner.look(8, 0, 1).$1, lessThan(ComboBanner.look(60, 0, 1).$1), reason: '길수록 크다');
  });

  testWidgets('콤보 배너 골든: x7·x12·x30·x60·x120 (막 처치한 순간 확대)', (tester) async {
    const counts = [7, 12, 30, 60, 120];
    tester.view
      ..physicalSize = const Size(1100, 160)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: 1100,
            height: 160,
            child: CustomPaint(painter: _Strip(counts)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/combo_banner.png'));
  });
}

class _Strip extends CustomPainter {
  _Strip(this.counts);
  final List<int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2F7FC4))
      ..scale(2);
    for (var i = 0; i < counts.length; i++) {
      ComboBanner().paint(
        canvas,
        40 + i * 110.0,
        10,
        counts[i],
        1060,
        1000,
        minKills: 5,
        baseColor: 0xFFFFD23F,
        onMilestone: (_) {},
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
