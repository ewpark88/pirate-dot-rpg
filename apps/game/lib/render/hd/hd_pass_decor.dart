import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 패스·상점 스킨 장식(S2 iap-contract — HD 결): 배 위에 얹는다(배 기준 좌표, 뱃머리 위, 칸 크기 size).
///   pass_s1 시즌 별 문장 깃발 · sprout 돛대 새싹·꽃 · golden_galleon 금빛 반짝이·뱃머리 금관 · jolly_flag 큰 해골 깃발·붉은 띠
///   · coral_yacht 뱃머리 산호·진주
class HdPassDecor {
  static const ids = {'pass_s1', 'sprout', 'golden_galleon', 'jolly_flag', 'coral_yacht'};

  final _k = HdKit();

  void over(Canvas c, String skin, Size size, double now) {
    final h = size.height;
    final w = size.width;
    _k.ink.strokeWidth = math.max<double>(1, w * 0.035);
    final bow = Offset(0, -h * 0.44);
    final mast = Offset(0, -h * 0.2);
    switch (skin) {
      case 'pass_s1':
        _flag(c, mast, w * 0.32, const Color(0xFF6A4AE0), const Color(0xFF3A2490), now);
        _star(c, mast + Offset(w * 0.22, 0), w * 0.09, const Color(0xFFFFE45A), const Color(0xFFD8901A));
      case 'sprout':
        for (final (x, y, a) in const [(-0.08, -0.32, -0.6), (0.08, -0.28, 0.6), (0.0, 0.05, -0.4)]) {
          final sway = math.sin(now / 400 + x * 10) * 0.12;
          _leaf(c, Offset(w * x, h * y), w * 0.16, a + sway);
        }
        _flower(c, bow + Offset(0, h * 0.04), w * 0.1);
      case 'golden_galleon':
        _crown(c, bow + Offset(0, h * 0.06), w * 0.22);
        for (var i = 0; i < 5; i++) {
          final u = (now / 900 + i / 5) % 1;
          final at = Offset(math.sin(i * 2.3) * w * 0.4, h * (0.4 - u * 0.8));
          _sparkle(c, at, w * 0.06 * math.sin(u * math.pi), const Color(0xFFFFF4B0));
        }
      case 'jolly_flag':
        _flag(c, mast, w * 0.42, const Color(0xFF2A2430), const Color(0xFF110D16), now);
        _skull(c, mast + Offset(w * 0.24, -w * 0.02), w * 0.09);
        final sash = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.06
          ..color = const Color(0xFFE83A3A);
        c.drawLine(Offset(-w * 0.32, h * 0.12), Offset(w * 0.32, h * 0.2), sash);
      case 'coral_yacht':
        for (final s in const [-1.0, 1.0]) {
          _coral(c, bow + Offset(s * w * 0.12, h * 0.08), w * 0.14, s);
        }
        _k.blob(
          c,
          Path()..addOval(Rect.fromCircle(center: bow + Offset(0, h * 0.1), radius: w * 0.06)),
          const Color(0xFFFFFFFF),
          const Color(0xFFD8D0E8),
          line: 0.5,
        );
    }
  }

  void _flag(Canvas c, Offset at, double len, Color light, Color dark, double now) {
    final wave = math.sin(now / 160) * len * 0.08;
    final p = Path()
      ..moveTo(at.dx, at.dy - len * 0.25)
      ..quadraticBezierTo(at.dx + len * 0.55, at.dy - len * 0.35 + wave, at.dx + len, at.dy - len * 0.2 + wave)
      ..lineTo(at.dx + len * 0.9, at.dy + len * 0.05 + wave)
      ..quadraticBezierTo(at.dx + len * 0.5, at.dy + len * 0.2 + wave, at.dx, at.dy + len * 0.2)
      ..close();
    _k.blob(c, p, light, dark, gloss: false, line: 0.6);
  }

  void _star(Canvas c, Offset at, double s, Color light, Color dark) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? s : s * 0.45;
      final q = at + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    p.close();
    _k.blob(c, p, light, dark, gloss: false, line: 0.5);
  }

  void _leaf(Canvas c, Offset at, double s, double angle) {
    c
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle);
    final p = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(s * 0.5, -s * 0.5, 0, -s)
      ..quadraticBezierTo(-s * 0.5, -s * 0.5, 0, 0)
      ..close();
    _k.blob(c, p, const Color(0xFFB8F07A), const Color(0xFF4AA83A), gloss: false, line: 0.5);
    c.restore();
  }

  void _flower(Canvas c, Offset at, double s) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      _k.blob(
        c,
        Path()..addOval(Rect.fromCircle(center: at + Offset(math.cos(a), math.sin(a)) * s * 0.6, radius: s * 0.45)),
        const Color(0xFFFFC8DC),
        const Color(0xFFFF7AA8),
        gloss: false,
        line: 0.4,
      );
    }
    _k.fill.color = const Color(0xFFFFE45A);
    c.drawCircle(at, s * 0.35, _k.fill);
  }

  void _crown(Canvas c, Offset at, double w) => _k.crown(c, at, w);

  void _sparkle(Canvas c, Offset at, double s, Color color) {
    if (s <= 0.3) return;
    _k.fill.color = color;
    final p = Path()
      ..moveTo(at.dx, at.dy - s * 2)
      ..lineTo(at.dx + s * 0.5, at.dy - s * 0.5)
      ..lineTo(at.dx + s * 2, at.dy)
      ..lineTo(at.dx + s * 0.5, at.dy + s * 0.5)
      ..lineTo(at.dx, at.dy + s * 2)
      ..lineTo(at.dx - s * 0.5, at.dy + s * 0.5)
      ..lineTo(at.dx - s * 2, at.dy)
      ..lineTo(at.dx - s * 0.5, at.dy - s * 0.5)
      ..close();
    c.drawPath(p, _k.fill);
  }

  void _skull(Canvas c, Offset at, double s) {
    _k.fill.color = const Color(0xFFF4F0E4);
    c.drawCircle(at, s, _k.fill);
    _k.fill.color = const Color(0xFF1B1726);
    for (final x in const [-1.0, 1.0]) {
      c.drawCircle(at + Offset(x * s * 0.35, -s * 0.05), s * 0.25, _k.fill);
    }
  }

  void _coral(Canvas c, Offset at, double s, double side) {
    final p = Path()
      ..moveTo(at.dx, at.dy)
      ..lineTo(at.dx + side * s * 0.1, at.dy - s * 0.6)
      ..moveTo(at.dx + side * s * 0.05, at.dy - s * 0.3)
      ..lineTo(at.dx + side * s * 0.4, at.dy - s * 0.7)
      ..moveTo(at.dx + side * s * 0.08, at.dy - s * 0.5)
      ..lineTo(at.dx - side * s * 0.25, at.dy - s * 0.85);
    _k.limb(c, p, const Color(0xFFFF7A8A), s * 0.14);
  }
}
