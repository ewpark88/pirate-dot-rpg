import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 코드로 그린 작은 해골 (보스 표시).
class SkullPainter extends CustomPainter {
  SkullPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final hole = Paint()..color = const Color(0xFF2B3A55);
    canvas
      ..drawOval(Rect.fromLTRB(w * 0.08, 0, w * 0.92, h * 0.78), fill)
      ..drawRRect(RRect.fromLTRBR(w * 0.26, h * 0.6, w * 0.74, h, Radius.circular(w * 0.1)), fill)
      ..drawOval(Rect.fromLTRB(w * 0.22, h * 0.3, w * 0.45, h * 0.55), hole)
      ..drawOval(Rect.fromLTRB(w * 0.55, h * 0.3, w * 0.78, h * 0.55), hole)
      ..drawPath(
        Path()
          ..moveTo(w * 0.5, h * 0.56)
          ..lineTo(w * 0.44, h * 0.68)
          ..lineTo(w * 0.56, h * 0.68)
          ..close(),
        hole,
      );
    final teeth = Paint()
      ..color = const Color(0xFF2B3A55)
      ..strokeWidth = math.max(1, w / 18);
    for (final x in [0.4, 0.5, 0.6]) {
      canvas.drawLine(Offset(w * x, h * 0.82), Offset(w * x, h * 0.98), teeth);
    }
  }

  @override
  bool shouldRepaint(SkullPainter old) => old.color != color;
}
