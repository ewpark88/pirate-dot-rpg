import 'package:flutter/material.dart';

// 선원 특색 아이콘 그림 (연사 막대 · 사거리 · 명중 화살) — crew_identity.dart에서 쓴다.

class IdRateBars extends StatelessWidget {
  const IdRateBars({required this.bars, required this.size, required this.color, super.key});

  final int bars;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(width: size * 0.08),
          Container(
            width: size * 0.18,
            height: size * (0.35 + 0.13 * i),
            decoration: BoxDecoration(
              color: i < bars ? color : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 사거리: 배(점)에서 뻗는 선 — 짧음 1칸 · 보통 2칸 · 김 3칸 (나머지는 옅게).
class IdRangePainter extends CustomPainter {
  IdRangePainter({required this.level, required this.color});

  final int level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final y = h * 0.55;
    final dot = Paint()..color = color;
    canvas.drawCircle(Offset(h * 0.12, y), h * 0.12, dot);
    final seg = (size.width - h * 0.3) / 3;
    for (var i = 0; i < 3; i++) {
      final p = Paint()
        ..color = i <= level ? color : color.withValues(alpha: 0.2)
        ..strokeWidth = h * 0.14
        ..strokeCap = StrokeCap.round;
      final x0 = h * 0.3 + seg * i + seg * 0.15;
      canvas.drawLine(Offset(x0, y), Offset(x0 + seg * 0.7, y), p);
    }
  }

  @override
  bool shouldRepaint(IdRangePainter old) => old.level != level || old.color != color;
}

/// 명중: 곧은 화살(즉시·예측 = 거의 맞음) / 휜 화살(빗나갈 수 있음).
class IdArrowPainter extends CustomPainter {
  IdArrowPainter({required this.curved, required this.color});

  final bool curved;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(w * 0.1, w * 0.6);
    if (curved) {
      path.quadraticBezierTo(w * 0.45, w * 0.05, w * 0.85, w * 0.45);
    } else {
      path.lineTo(w * 0.85, w * 0.6);
    }
    canvas.drawPath(path, p);
    final tip = curved ? Offset(w * 0.85, w * 0.45) : Offset(w * 0.85, w * 0.6);
    final back = curved ? const Offset(-0.32, -0.05) : const Offset(-0.25, -0.2);
    final back2 = curved ? const Offset(-0.12, -0.32) : const Offset(-0.25, 0.2);
    canvas
      ..drawLine(tip, tip + back * w, p)
      ..drawLine(tip, tip + back2 * w, p);
  }

  @override
  bool shouldRepaint(IdArrowPainter old) => old.curved != curved || old.color != color;
}
