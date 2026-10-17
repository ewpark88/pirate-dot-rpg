import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/top/top_enemy_death.dart';

/// 잡몹 종류별 처치 연출(S1): 유형 묶음·시안(유형 7 × 진행 0.1·0.35·0.6·0.85, 몸은 원으로 대신).
class _Sheet extends CustomPainter {
  final death = TopEnemyDeath();
  final body = Paint()..color = const Color(0xFFE8503A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1C8FB0));
    const types = [
      DeathType.shell,
      DeathType.bloat,
      DeathType.fish,
      DeathType.bird,
      DeathType.bone,
      DeathType.spirit,
      DeathType.sink,
    ];
    for (var row = 0; row < types.length; row++) {
      for (var col = 0; col < 4; col++) {
        final t = const [0.1, 0.35, 0.6, 0.85][col];
        final at = Offset(50 + col * 80.0, 50 + row * 80.0);
        const s = 26.0;
        final (dx, dy, sx, sy, turn, alpha) = TopEnemyDeath.pose(types[row], t);
        if (alpha > 0) {
          canvas
            ..save()
            ..translate(at.dx + dx * s, at.dy + dy * s)
            ..rotate(turn)
            ..scale(sx, sy)
            ..drawOval(
              const Rect.fromLTWH(-13, -10, 26, 20),
              body..color = const Color(0xFFE8503A).withValues(alpha: alpha),
            )
            ..drawCircle(const Offset(5, -4), 3, Paint()..color = Colors.white.withValues(alpha: alpha))
            ..restore();
        }
        death.particles(canvas, types[row], at, t, s, 7);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  test('잡몹 HD 종은 모두 공용 펑이 아닌 유형으로 묶인다', () {
    final pop = [
      for (final k in hdEnemies.keys)
        if (TopEnemyDeath.typeOf(k) == DeathType.pop) k,
    ];
    expect(pop, isEmpty);
    expect(TopEnemyDeath.typeOf('crab'), DeathType.shell);
    expect(TopEnemyDeath.typeOf('ghostjelly'), DeathType.spirit);
    expect(TopEnemyDeath.typeOf('skeleton'), DeathType.bone);
  });

  testWidgets('처치 연출 시안(유형 × 진행)', (tester) async {
    const size = Size(340, 580);
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_enemy_death.png'));
  });
}
