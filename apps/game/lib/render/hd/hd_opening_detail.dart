part of 'hd_opening.dart';

/// 오프닝 5컷 배경 디테일(S1 'HD 다듬기 — 옥토·보스·동료가 얹히는 배경'): 원경 섬·물 반짝임·물고기·비·파도 거품·갑판 소품·
/// 빛줄기·새 떼. 캐릭터가 얹히는 가운데는 비우고 가장자리·원경 위주(hd_opening.dart 300줄 한도로 나눔).
extension _OpeningDetail on _OpeningPainter {
  /// 수평선 원경 섬(실루엣 + 야자수 하나).
  void _islands(Canvas c, Size s, double horizon, Color color, {bool palm = false}) {
    _p.color = color;
    for (final (x, w, h) in const [(0.12, 0.22, 0.05), (0.86, 0.18, 0.04)]) {
      c.drawOval(Rect.fromCenter(center: Offset(s.width * x, horizon), width: s.width * w, height: s.height * h), _p);
    }
    if (!palm) return;
    final base = Offset(s.width * 0.13, horizon - s.height * 0.02);
    final top = base + Offset(s.width * 0.02, -s.height * 0.07);
    _k.ink.strokeWidth = s.width * 0.008;
    c.drawLine(base, top, _k.ink..color = color);
    _k.ink.color = HdKit.inkColor;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi * (0.1 + i * 0.2);
      c.drawLine(top, top + Offset(math.cos(a), math.sin(a) * 0.5) * s.width * 0.05, _k.ink..color = color);
    }
    _k.ink.color = HdKit.inkColor;
  }

  /// 해 아래 수면에 흔들리는 반짝임 줄.
  void _glitter(Canvas c, Size s, Offset sun, double top, Color color) {
    for (var i = 0; i < 9; i++) {
      final y = top + (i + 1) * s.height * 0.035;
      final w = s.width * (0.04 + 0.02 * math.sin(_t / 400 + i));
      final x = sun.dx + math.sin(_t / 700 + i * 1.7) * s.width * 0.03;
      _p.color = color.withValues(alpha: 0.7 - i * 0.06);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: w, height: s.height * 0.006),
          const Radius.circular(3),
        ),
        _p,
      );
    }
  }

  /// 뛰어오르는 물고기(포물선, 6초에 한 번).
  void _fish(Canvas c, Size s, double top) {
    final u = (_t / 6000 * 2) % 1;
    if (u > 0.4) return;
    final k = u / 0.4;
    final p = Offset(s.width * (0.72 + 0.12 * k), top + s.height * 0.08 - math.sin(k * math.pi) * s.height * 0.08);
    c
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(-0.8 + 1.6 * k);
    _k.blob(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset.zero, width: s.width * 0.05, height: s.width * 0.025)),
      const Color(0xFFFFB45A),
      const Color(0xFFE0702A),
      gloss: false,
      line: 0.5,
    );
    c.restore();
  }

  /// 폭풍 비: 비스듬한 빗줄 + 파도 머리 흰 거품.
  void _rain(Canvas c, Size s, double sea) {
    _p
      ..color = const Color(0x55C8D8FF)
      ..strokeWidth = s.width * 0.004;
    for (var i = 0; i < 40; i++) {
      final x = (i * 37.0 + _t * 0.4) % (s.width + 60) - 30;
      final y = (i * 53.0 + _t * 1.2) % s.height;
      c.drawLine(Offset(x, y), Offset(x - s.width * 0.02, y + s.height * 0.04), _p);
    }
    _p.color = const Color(0xCCE8F0FF);
    for (var i = 0; i < 7; i++) {
      final x = s.width * (i / 7 + 0.05) + math.sin(_t / 500 + i) * 6;
      final y = sea + s.height * (0.03 + (i % 3) * 0.05);
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: s.width * 0.06, height: s.height * 0.008), _p);
    }
  }

  /// 갑판 양옆 소품: 통 둘·보물상자·감긴 밧줄·등불(흔들림) — 가운데(동료 그림 자리)는 비운다.
  void _deckProps(Canvas c, Size s) {
    final floor = s.height * 0.62;
    final w = s.width;
    for (final x in const [0.08, 0.18]) {
      final barrel = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * (x - 0.05), floor - w * 0.12, w * 0.1, w * 0.12),
            Radius.circular(w * 0.02),
          ),
        );
      _k.blob(c, barrel, const Color(0xFFB07A4A), const Color(0xFF5A3A1A), line: 0.6);
      _p.color = const Color(0xFF4A4458);
      c
        ..drawRect(Rect.fromLTWH(w * (x - 0.05), floor - w * 0.1, w * 0.1, w * 0.012), _p)
        ..drawRect(Rect.fromLTWH(w * (x - 0.05), floor - w * 0.035, w * 0.1, w * 0.012), _p);
    }
    final chest = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.78, floor - w * 0.1, w * 0.16, w * 0.1),
          Radius.circular(w * 0.015),
        ),
      );
    _k.blob(c, chest, const Color(0xFFC08A4A), const Color(0xFF6A3A1A), line: 0.6);
    _p.color = const Color(0xFFFFD45A);
    c
      ..drawRect(Rect.fromLTWH(w * 0.78, floor - w * 0.06, w * 0.16, w * 0.014), _p)
      ..drawCircle(Offset(w * 0.86, floor - w * 0.045), w * 0.012, _p);
    // 감긴 밧줄
    _k.ink.strokeWidth = w * 0.01;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..color = const Color(0xFFD8B87A);
    for (var i = 0; i < 3; i++) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.64, floor - w * 0.015),
          width: w * (0.1 - i * 0.025),
          height: w * (0.035 - i * 0.008),
        ),
        _p,
      );
    }
    _p.style = PaintingStyle.fill;
    // 등불(깃발 줄에 매달려 흔들, 노란 빛 번짐)
    for (final x in const [0.3, 0.7]) {
      final swing = math.sin(_t / 600 + x * 5) * w * 0.01;
      final at = Offset(w * x + swing, s.height * 0.2);
      _p.color = const Color(0x55FFD45A);
      c.drawCircle(at, w * 0.05, _p);
      _k.blob(
        c,
        Path()..addOval(Rect.fromCircle(center: at, radius: w * 0.022)),
        const Color(0xFFFFF0A0),
        const Color(0xFFE0A030),
        line: 0.5,
      );
    }
  }

  /// 해에서 퍼지는 빛줄기(천천히 돎) + 멀리 새 떼.
  void _sunRays(Canvas c, Size s, Offset sun) {
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + _t / 6000;
      final p = Path()
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(sun.dx + math.cos(a - 0.06) * s.width, sun.dy + math.sin(a - 0.06) * s.width)
        ..lineTo(sun.dx + math.cos(a + 0.06) * s.width, sun.dy + math.sin(a + 0.06) * s.width)
        ..close();
      _p.color = const Color(0x18FFF0C0);
      c.drawPath(p, _p);
    }
    _k.ink.strokeWidth = s.width * 0.006;
    for (var i = 0; i < 4; i++) {
      final at = Offset(s.width * (0.2 + i * 0.07) + _t / 6000 * 20, s.height * (0.22 + (i % 2) * 0.03));
      final f = math.sin(_t / 200 + i) * s.width * 0.008;
      c
        ..drawLine(at, at + Offset(-s.width * 0.02, -s.width * 0.01 + f), _k.ink)
        ..drawLine(at, at + Offset(s.width * 0.02, -s.width * 0.01 + f), _k.ink);
    }
  }
}
