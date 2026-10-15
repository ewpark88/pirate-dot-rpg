import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 코드로 그린 보물 상자 — 나무 몸통 + 금 띠 + 자물쇠, [lid] 0→1로 뚜껑이 뒤로 젖혀진다.
class ChestPainter extends CustomPainter {
  ChestPainter({required this.lid});

  final double lid;

  static const _wood = Color(0xFFB8672E);
  static const _woodDark = Color(0xFF7A3E17);
  static const _gold = Color(0xFFFFC93C);
  static const _ink = Color(0xFF3A2410);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final body = RRect.fromLTRBR(w * 0.06, h * 0.42, w * 0.94, h * 0.98, const Radius.circular(8));
    // 안쪽 빛 (열릴수록 밝게).
    if (lid > 0) {
      canvas.drawRect(
        Rect.fromLTRB(w * 0.1, h * 0.36, w * 0.9, h * 0.5),
        Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: lid.clamp(0, 1).toDouble()),
      );
    }
    canvas
      ..drawRRect(
        body,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_wood, _woodDark],
          ).createShader(body.outerRect),
      )
      // 금 띠 2줄.
      ..drawRect(Rect.fromLTRB(w * 0.2, h * 0.42, w * 0.3, h * 0.98), Paint()..color = _gold)
      ..drawRect(Rect.fromLTRB(w * 0.7, h * 0.42, w * 0.8, h * 0.98), Paint()..color = _gold)
      ..drawRRect(body, stroke)
      // 자물쇠.
      ..drawRRect(
        RRect.fromLTRBR(w * 0.43, h * 0.5, w * 0.57, h * 0.68, const Radius.circular(3)),
        Paint()..color = _gold,
      )
      ..drawRRect(RRect.fromLTRBR(w * 0.43, h * 0.5, w * 0.57, h * 0.68, const Radius.circular(3)), stroke);

    // 뚜껑: 뒤쪽 경첩(위 가장자리)을 축으로 위로 젖힌다 — 세로로 눌리며 올라간다.
    final open = lid.clamp(0, 1.2).toDouble();
    final lidH = h * 0.34 * (1 - 0.8 * open.clamp(0, 1));
    final lidTop = h * 0.42 - lidH - h * 0.18 * open;
    final lidRect = RRect.fromLTRBAndCorners(
      w * 0.04,
      lidTop,
      w * 0.96,
      lidTop + lidH,
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas
      ..drawRRect(
        lidRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(_wood, Colors.white, 0.15)!, _wood],
          ).createShader(lidRect.outerRect),
      )
      ..drawRect(Rect.fromLTRB(w * 0.2, lidTop, w * 0.3, lidTop + lidH), Paint()..color = _gold)
      ..drawRect(Rect.fromLTRB(w * 0.7, lidTop, w * 0.8, lidTop + lidH), Paint()..color = _gold)
      ..drawRRect(lidRect, stroke);
  }

  @override
  bool shouldRepaint(ChestPainter old) => old.lid != lid;
}

/// 상자 뒤 빛줄기 (금빛 부채꼴 12개).
class RaysPainter extends CustomPainter {
  const RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFE27A).withValues(alpha: 0.9), const Color(0x00FFE27A)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    const n = 12;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.1), c.dy + r * math.sin(a - 0.1))
        ..lineTo(c.dx + r * math.cos(a + 0.1), c.dy + r * math.sin(a + 0.1))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(RaysPainter old) => false;
}
