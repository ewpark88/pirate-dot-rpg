import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';

/// 스킨 미리보기 배 — 선체·돛·깃발 색만 보이는 코드 그림.
/// 렌더(S3)가 스킨 팔레트 바꾸기 그림 함수를 주면 그것으로 바꾼다(전장·강화 화면과 같은 그림).
class SkinPreviewShip extends StatelessWidget {
  const SkinPreviewShip({required this.skin, this.size = 72, super.key});

  /// null = 기본 배.
  final SkinDef? skin;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 0.8),
    painter: _ShipPainter(
      hull: skin?.hull ?? const Color(0xFF9A5B2E),
      sail: skin?.sail ?? const Color(0xFFF5EEDC),
      flag: skin?.flag ?? const Color(0xFF2B3A55),
    ),
  );
}

class _ShipPainter extends CustomPainter {
  _ShipPainter({required this.hull, required this.sail, required this.flag});

  final Color hull;
  final Color sail;
  final Color flag;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = Paint()
      ..color = const Color(0xFF2B3A55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w / 40)
      ..strokeJoin = StrokeJoin.round;
    // 물결.
    canvas
      ..drawRRect(
        RRect.fromLTRBR(0, h * 0.86, w, h, Radius.circular(h * 0.07)),
        Paint()..color = const Color(0xFF7CC8F2),
      )
      // 돛대.
      ..drawLine(Offset(w * 0.5, h * 0.08), Offset(w * 0.5, h * 0.66), ink);
    // 돛 (살짝 부푼 사각형).
    final sailPath = Path()
      ..moveTo(w * 0.24, h * 0.18)
      ..quadraticBezierTo(w * 0.5, h * 0.12, w * 0.76, h * 0.18)
      ..quadraticBezierTo(w * 0.82, h * 0.38, w * 0.76, h * 0.58)
      ..quadraticBezierTo(w * 0.5, h * 0.52, w * 0.24, h * 0.58)
      ..quadraticBezierTo(w * 0.18, h * 0.38, w * 0.24, h * 0.18)
      ..close();
    canvas
      ..drawPath(sailPath, Paint()..color = sail)
      ..drawPath(sailPath, ink);
    // 깃발.
    final flagPath = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.7, h * 0.11)
      ..lineTo(w * 0.5, h * 0.16)
      ..close();
    canvas
      ..drawPath(flagPath, Paint()..color = flag)
      ..drawPath(flagPath, ink);
    // 선체 (위가 넓은 배 모양 + 밝은 띠).
    final hullPath = Path()
      ..moveTo(w * 0.06, h * 0.62)
      ..lineTo(w * 0.94, h * 0.62)
      ..quadraticBezierTo(w * 0.86, h * 0.9, w * 0.72, h * 0.9)
      ..lineTo(w * 0.28, h * 0.9)
      ..quadraticBezierTo(w * 0.14, h * 0.9, w * 0.06, h * 0.62)
      ..close();
    canvas
      ..drawPath(hullPath, Paint()..color = hull)
      ..drawRect(
        Rect.fromLTRB(w * 0.1, h * 0.66, w * 0.9, h * 0.7),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      )
      ..drawPath(hullPath, ink);
  }

  @override
  bool shouldRepaint(_ShipPainter old) => old.hull != hull || old.sail != sail || old.flag != flag;
}
