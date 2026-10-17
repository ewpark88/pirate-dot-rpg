import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/top_boss_signature.dart';

import 'helpers.dart';

/// 새 보스 18종 '보이는 개성'(S1): 특성 발동 때 보스마다 다른 표식(시안: 몸은 원으로 대신, 발동 0.35초).
const _bosses = [
  'coral_golem',
  'clown_king',
  'pearl_clam',
  'storm_eagle',
  'cloud_whale',
  'thunder_crab',
  'frost_yeti',
  'ice_narwhal',
  'snow_owl_ship',
  'magma_golem',
  'fire_salamander',
  'ash_dragon',
  'abyss_eye',
  'lantern_eel',
  'bone_shark',
  'banshee_queen',
  'cursed_bell',
  'ghost_kraken',
];

class _Sheet extends CustomPainter {
  final sig = TopBossSignature();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1C8FB0));
    for (var i = 0; i < _bosses.length; i++) {
      final at = Offset(60 + (i % 3) * 110.0, 70 + (i ~/ 3) * 115.0);
      canvas.drawCircle(at, 24, Paint()..color = const Color(0xFF5A4A6A));
      sig.paint(canvas, _bosses[i], at, 26, 320, 1234);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  test('새 보스 18종은 모두 표식이 있고, 표에 있는 보스다', () {
    final ids = {for (final b in tables.regions.bosses.values) b.id};
    for (final b in _bosses) {
      expect(TopBossSignature.has(b), isTrue, reason: b);
      expect(ids, contains(b));
    }
  });

  testWidgets('보스 표식 시안(18종)', (tester) async {
    const size = Size(340, 720);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Sheet()),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_boss_signature.png'));
  });
}
