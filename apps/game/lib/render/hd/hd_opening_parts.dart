part of 'hd_opening.dart';

/// 오프닝 컷 소품(지도·낡은 배·번개·촉수·갑판·깃발 줄·반짝이·빛 길·출항 배) — hd_opening.dart 300줄 한도로 나눔.
extension _OpeningParts on _OpeningPainter {
  /// 떠 있는 보물지도(말린 양피지·점선 길·붉은 X).
  void _map(Canvas c, Offset at, double w) {
    final bob = math.sin(_t / 500) * w * 0.03;
    c
      ..save()
      ..translate(at.dx, at.dy + bob)
      ..rotate(-0.08);
    final h = w * 0.66;
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(w * 0.04)),
      );
    _k.blob(c, body, const Color(0xFFFFF0C8), const Color(0xFFE0B878));
    for (final s in const [-1.0, 1.0]) {
      _k.blob(
        c,
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(s * w * 0.5, 0), width: w * 0.08, height: h * 1.08),
            Radius.circular(w * 0.04),
          ),
        ),
        const Color(0xFFE8C890),
        const Color(0xFFB08850),
        gloss: false,
      );
    }
    final dash = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.015
      ..color = const Color(0xFF8A5A30);
    final route = Path()
      ..moveTo(-w * 0.35, h * 0.2)
      ..quadraticBezierTo(-w * 0.1, -h * 0.3, w * 0.1, h * 0.05)
      ..quadraticBezierTo(w * 0.22, h * 0.25, w * 0.28, -h * 0.15);
    for (final m in route.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += w * 0.06) {
        c.drawPath(m.extractPath(d, d + w * 0.03), dash);
      }
    }
    final x = Offset(w * 0.3, -h * 0.18);
    final cross = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.035
      ..color = const Color(0xFFE83A3A);
    c
      ..drawLine(x + Offset(-w * 0.05, -w * 0.05), x + Offset(w * 0.05, w * 0.05), cross)
      ..drawLine(x + Offset(w * 0.05, -w * 0.05), x + Offset(-w * 0.05, w * 0.05), cross)
      ..restore();
  }

  /// 낡은 작은 배(옆모습): 기운 돛대·덧댄 판자·찢긴 돛.
  void _oldBoat(Canvas c, Offset at, double w) {
    final rock = math.sin(_t / 700) * 0.05;
    c
      ..save()
      ..translate(at.dx, at.dy + math.sin(_t / 500) * w * 0.02)
      ..rotate(rock);
    final hull = Path()
      ..moveTo(-w * 0.5, -w * 0.05)
      ..lineTo(w * 0.5, -w * 0.08)
      ..quadraticBezierTo(w * 0.42, w * 0.22, 0, w * 0.24)
      ..quadraticBezierTo(-w * 0.4, w * 0.22, -w * 0.5, -w * 0.05)
      ..close();
    _k.blob(c, hull, const Color(0xFFB07A4A), const Color(0xFF5A3418));
    // 덧댄 판자 두 장
    for (final (x, y) in const [(-0.22, 0.06), (0.18, 0.1)]) {
      _k.blob(
        c,
        Path()..addRect(Rect.fromCenter(center: Offset(x * w, y * w), width: w * 0.14, height: w * 0.07)),
        const Color(0xFFD8A870),
        const Color(0xFF8A5A30),
        gloss: false,
        line: 0.5,
      );
    }
    // 기운 돛대 + 찢긴 돛
    _k.limb(
      c,
      Path()
        ..moveTo(-w * 0.02, -w * 0.06)
        ..lineTo(w * 0.04, -w * 0.62),
      const Color(0xFF8A5A30),
      w * 0.035,
    );
    final flap = math.sin(_t / 300) * w * 0.02;
    final sail = Path()
      ..moveTo(w * 0.03, -w * 0.58)
      ..quadraticBezierTo(w * 0.32 + flap, -w * 0.42, w * 0.3, -w * 0.16)
      ..lineTo(w * 0.22, -w * 0.2)
      ..lineTo(w * 0.18, -w * 0.12)
      ..lineTo(w * 0.01, -w * 0.12)
      ..close();
    _k.blob(c, sail, const Color(0xFFF4ECD8), const Color(0xFFC8B898), line: 0.7);
    c.restore();
  }

  void _lightning(Canvas c, Size s) {
    final phase = (_t % 2400) / 2400;
    if (phase < 0.08) {
      _p.color = Color.fromRGBO(255, 255, 255, 0.35 * (1 - phase / 0.08));
      c.drawRect(Offset.zero & s, _p);
      final bolt = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.shortestSide * 0.012
        ..color = const Color(0xFFFFF6A0);
      final p = Path()..moveTo(s.width * 0.72, 0);
      var x = s.width * 0.72;
      for (var i = 1; i <= 6; i++) {
        x += (i.isEven ? 1 : -1) * s.width * 0.04;
        p.lineTo(x, s.height * 0.09 * i);
      }
      c.drawPath(p, bolt);
    }
  }

  /// 폭풍 바다에서 솟는 촉수 실루엣 4 + 멀리 빛나는 눈 둘.
  void _tentacles(Canvas c, Size s) {
    final base = s.height * 0.62;
    for (final (x, h, ph) in const [(0.12, 0.38, 0.0), (0.3, 0.3, 1.3), (0.72, 0.34, 2.1), (0.9, 0.42, 3.0)]) {
      final sway = math.sin(_t / 700 + ph) * s.width * 0.04;
      final tip = Offset(x * s.width + sway, base - h * s.height);
      final p = Path()
        ..moveTo(x * s.width - s.width * 0.05, base)
        ..quadraticBezierTo(x * s.width - s.width * 0.06 + sway * 0.5, base - h * s.height * 0.5, tip.dx, tip.dy)
        ..quadraticBezierTo(
          tip.dx + s.width * 0.05,
          tip.dy + s.height * 0.04,
          tip.dx + s.width * 0.02,
          tip.dy + s.height * 0.07,
        )
        ..quadraticBezierTo(
          x * s.width + s.width * 0.02 + sway * 0.5,
          base - h * s.height * 0.45,
          x * s.width + s.width * 0.05,
          base,
        )
        ..close();
      _k.blob(c, p, const Color(0xFF5A2A7A), const Color(0xFF1A0A2A), gloss: false);
    }
    final glow = 0.7 + 0.3 * math.sin(_t / 400);
    for (final sx in const [-1.0, 1.0]) {
      final at = Offset(s.width * 0.5 + sx * s.width * 0.08, s.height * 0.5);
      _p.color = Color.fromRGBO(255, 60, 40, 0.3 * glow);
      c.drawCircle(at, s.width * 0.05, _p);
      _p.color = Color.fromRGBO(255, 220, 90, glow);
      c.drawOval(Rect.fromCenter(center: at, width: s.width * 0.05, height: s.width * 0.025), _p);
    }
  }

  void _deck(Canvas c, Size s) {
    final top = s.height * 0.55;
    _p.color = const Color(0xFFB07A4A);
    c.drawRect(Rect.fromLTRB(0, top, s.width, s.height), _p);
    final line = Paint()
      ..strokeWidth = s.shortestSide * 0.005
      ..color = const Color(0x665A3418);
    for (var i = 0; i < 8; i++) {
      final y = top + (s.height - top) * i / 8;
      c.drawLine(Offset(0, y), Offset(s.width, y), line);
    }
    // 난간
    _k.blob(
      c,
      Path()..addRect(Rect.fromLTRB(-4, top - s.height * 0.03, s.width + 4, top + s.height * 0.015)),
      const Color(0xFFD8A060),
      const Color(0xFF7A4A22),
      gloss: false,
    );
  }

  void _bunting(Canvas c, Size s) {
    final sag = s.height * 0.06;
    const colors = [Color(0xFFFF5A5A), Color(0xFFFFD45A), Color(0xFF5AC8FF), Color(0xFF6AD86A)];
    for (var i = 0; i < 9; i++) {
      final u = i / 8;
      final x = u * s.width;
      final y = s.height * 0.12 + 4 * u * (1 - u) * sag + math.sin(_t / 400 + i) * 2;
      final p = Path()
        ..moveTo(x - s.width * 0.04, y)
        ..lineTo(x + s.width * 0.04, y)
        ..lineTo(x, y + s.width * 0.08)
        ..close();
      _k.blob(c, p, colors[i % 4], Color.lerp(colors[i % 4], const Color(0xFF000000), 0.3)!, gloss: false, line: 0.5);
    }
  }

  void _sparkles(Canvas c, Size s, Color color) {
    for (var i = 0; i < 12; i++) {
      final ph = (_t / 1200 + i * 0.37) % 1;
      final at = Offset((i * 131.7) % s.width, (i * 71.3) % (s.height * 0.6));
      final r = s.shortestSide * 0.012 * math.sin(ph * math.pi);
      if (r <= 0) continue;
      _p.color = color;
      final p = Path()
        ..moveTo(at.dx, at.dy - r * 2)
        ..lineTo(at.dx + r * 0.5, at.dy - r * 0.5)
        ..lineTo(at.dx + r * 2, at.dy)
        ..lineTo(at.dx + r * 0.5, at.dy + r * 0.5)
        ..lineTo(at.dx, at.dy + r * 2)
        ..lineTo(at.dx - r * 0.5, at.dy + r * 0.5)
        ..lineTo(at.dx - r * 2, at.dy)
        ..lineTo(at.dx - r * 0.5, at.dy - r * 0.5)
        ..close();
      c.drawPath(p, _p);
    }
  }

  void _lightPath(Canvas c, Size s) {
    final p = Path()
      ..moveTo(s.width * 0.45, s.height * 0.52)
      ..lineTo(s.width * 0.55, s.height * 0.52)
      ..lineTo(s.width * 0.8, s.height)
      ..lineTo(s.width * 0.2, s.height)
      ..close();
    _p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xCCFFE07A), Color(0x00FFE07A)],
    ).createShader(p.getBounds());
    c.drawPath(p, _p);
    _p.shader = null;
  }

  /// 돛 가득 편 배(옆모습, 뒤에서 본 3/4): 선체·돛 둘·깃발.
  void _sailShip(Canvas c, Offset at, double w) {
    c
      ..save()
      ..translate(at.dx, at.dy + math.sin(_t / 600) * w * 0.02)
      ..rotate(math.sin(_t / 800) * 0.03);
    final hull = Path()
      ..moveTo(-w * 0.55, -w * 0.02)
      ..lineTo(w * 0.55, -w * 0.06)
      ..quadraticBezierTo(w * 0.45, w * 0.22, 0, w * 0.24)
      ..quadraticBezierTo(-w * 0.45, w * 0.22, -w * 0.55, -w * 0.02)
      ..close();
    _k.blob(c, hull, const Color(0xFF8A4A2A), const Color(0xFF3E1C0E));
    _k.ink.strokeWidth = w * 0.02;
    for (final (x, h) in const [(-0.18, 0.7), (0.18, 0.85)]) {
      _k.limb(
        c,
        Path()
          ..moveTo(x * w, -w * 0.04)
          ..lineTo(x * w, -h * w),
        const Color(0xFF6A3A1A),
        w * 0.03,
      );
      final puff = math.sin(_t / 500 + x * 9) * w * 0.02;
      final sail = Path()
        ..moveTo(x * w - w * 0.2, -h * w + w * 0.08)
        ..quadraticBezierTo(x * w, -h * w - w * 0.02, x * w + w * 0.2, -h * w + w * 0.08)
        ..quadraticBezierTo(x * w + w * 0.24 + puff, -h * w * 0.55, x * w + w * 0.2, -w * 0.12)
        ..lineTo(x * w - w * 0.2, -w * 0.12)
        ..quadraticBezierTo(x * w - w * 0.24 - puff, -h * w * 0.55, x * w - w * 0.2, -h * w + w * 0.08)
        ..close();
      _k.blob(c, sail, const Color(0xFFFFF8E8), const Color(0xFFE8C8A8));
    }
    final flag = Path()
      ..moveTo(w * 0.18, -w * 0.85)
      ..quadraticBezierTo(w * 0.3, -w * 0.9 + math.sin(_t / 200) * w * 0.02, w * 0.38, -w * 0.84)
      ..lineTo(w * 0.18, -w * 0.78)
      ..close();
    _k.blob(c, flag, const Color(0xFF3A3A4A), const Color(0xFF1A1424), gloss: false, line: 0.5);
    c.restore();
  }
}
