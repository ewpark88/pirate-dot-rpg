import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 도트 고리 (CircularProgressIndicator 대신): 원 둘레에 도트 칸을 놓고, 12시부터 시계 방향으로 [value]만큼 칠한다.
class PixelRing extends StatelessWidget {
  const PixelRing({required this.value, this.color = PixelPalette.gold, super.key});

  /// 0~1.
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(value.clamp(0, 1), color, pixelUnit(context)),
    size: Size.infinite,
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value, this.color, this.unit);

  final double value;
  final Color color;
  final double unit;

  /// 둘레 칸 수.
  static const _cells = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = unit * 2;
    final r = size.shortestSide / 2 - dot;
    final c = size.center(Offset.zero);
    final on = Paint()..color = color;
    final off = Paint()..color = PixelPalette.outline;
    final lit = (value * _cells).ceil();
    for (var i = 0; i < _cells; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / _cells;
      // 칸 위치를 도트 격자에 맞춘다.
      final x = ((c.dx + r * math.cos(a)) / unit).round() * unit;
      final y = ((c.dy + r * math.sin(a)) / unit).round() * unit;
      canvas.drawRect(Rect.fromLTWH(x - dot / 2, y - dot / 2, dot, dot), i < lit ? on : off);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.unit != unit;
}
