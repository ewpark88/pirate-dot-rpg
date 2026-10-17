part of 'hd_cartoon.dart';

/// HD 카툰 시범 보스(크라켄) — hd_cartoon.dart 300줄 한도로 나눔.
extension _HdBoss on HdCartoon {
  // ---------- 크라켄(보스) ----------
  void _kraken(Canvas c, double r, double t) {
    const purple = Color(0xFFB062FF);
    const purpleD = Color(0xFF5A2AA8);
    // 촉수 8(뒤 → 앞)
    for (var i = 0; i < 8; i++) {
      final a = math.pi * (0.15 + 0.7 * i / 7);
      final wig = math.sin(t / 240 + i) * 0.25;
      final p = Path()..moveTo(math.cos(a) * r * 0.4, r * 0.3);
      final ex = math.cos(a + wig * 0.3) * r * 1.35;
      final ey = r * 0.3 + math.sin(a) * r * 0.85;
      p.quadraticBezierTo(math.cos(a - wig) * r * 1.1, r * 0.2 + math.sin(a) * r * 0.2, ex, ey);
      c
        ..drawPath(
          p,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.3 + _ink.strokeWidth * 2
            ..color = const Color(0xFF1A1424),
        )
        ..drawPath(
          p,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.3
            ..color = i.isEven ? purple : const Color(0xFF9A4AF0),
        );
      // 빨판
      _fill.color = const Color(0xFFFFC8F0);
      c.drawCircle(Offset(ex, ey) * 0.82 + Offset(0, r * 0.05), r * 0.05, _fill);
    }
    // 머리(망토)
    final head = Path()
      ..moveTo(-r * 0.85, r * 0.35)
      ..cubicTo(-r * 1.05, -r * 1.3, r * 1.05, -r * 1.3, r * 0.85, r * 0.35)
      ..quadraticBezierTo(0, r * 0.6, -r * 0.85, r * 0.35)
      ..close();
    _blob(c, head, const Color(0xFFD8A0FF), purpleD);
    // 점박이
    _fill.color = const Color(0x667A3AD8);
    for (final (dx, dy, s) in const [(-0.45, -0.55, 0.12), (0.5, -0.4, 0.1), (0.1, -0.85, 0.08)]) {
      c.drawCircle(Offset(dx * r, dy * r), s * r, _fill);
    }
    // 금관
    final crown = Path()
      ..moveTo(-r * 0.35, -r * 0.92)
      ..lineTo(-r * 0.3, -r * 1.25)
      ..lineTo(-r * 0.12, -r * 1.05)
      ..lineTo(0, -r * 1.35)
      ..lineTo(r * 0.12, -r * 1.05)
      ..lineTo(r * 0.3, -r * 1.25)
      ..lineTo(r * 0.35, -r * 0.92)
      ..close();
    _blob(c, crown, const Color(0xFFFFE27A), const Color(0xFFE0A020));
    // 화난 큰 눈 + 이빨 입
    for (final s in const [-1.0, 1.0]) {
      _eye(c, Offset(s * r * 0.36, -r * 0.2), r * 0.42, angry: true, look: s * -0.4);
    }
    final mouth = Path()
      ..moveTo(-r * 0.3, r * 0.15)
      ..quadraticBezierTo(0, r * 0.42, r * 0.3, r * 0.15)
      ..close();
    _fill.color = const Color(0xFF6A1424);
    c
      ..drawPath(mouth, _fill)
      ..drawPath(mouth, _ink);
    _fill.color = const Color(0xFFFFFFFF);
    for (final s in const [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(s * r * 0.18, r * 0.17)
        ..lineTo(s * r * 0.1, r * 0.3)
        ..lineTo(s * r * 0.03, r * 0.19)
        ..close();
      c.drawPath(p, _fill);
    }
  }
}
