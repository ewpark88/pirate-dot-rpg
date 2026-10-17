part of 'top_boss_signature.dart';

/// 보스 표식 도형 도우미(300줄 한도로 나눔).
extension _Shapes on TopBossSignature {
  void _hex(Offset p, double s, double rot) {
    _path.reset();
    for (var i = 0; i < 6; i++) {
      final q = p + Offset(math.cos(rot + i * math.pi / 3), math.sin(rot + i * math.pi / 3)) * s;
      i == 0 ? _path.moveTo(q.dx, q.dy) : _path.lineTo(q.dx, q.dy);
    }
    _path.close();
  }

  void _spiral(Canvas c, Offset at, double r, double phase, int arms, Color color, double a, double w) {
    _line
      ..strokeWidth = w
      ..color = color.withValues(alpha: 0.8 * a);
    for (var arm = 0; arm < arms; arm++) {
      _path.reset();
      for (var k = 0; k <= 20; k++) {
        final u = k / 20;
        final aa = phase * 2 * math.pi + arm * 2 * math.pi / arms + u * 3;
        final p = at + Offset(math.cos(aa), math.sin(aa)) * r * (0.3 + 0.7 * u);
        k == 0 ? _path.moveTo(p.dx, p.dy) : _path.lineTo(p.dx, p.dy);
      }
      c.drawPath(_path, _line);
    }
  }

  void _leaf(Canvas c, Offset p, double rot, double len, Color color, double a) {
    c
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(rot);
    _fill.color = color.withValues(alpha: a);
    c
      ..drawOval(Rect.fromCenter(center: Offset.zero, width: len, height: len * 0.35), _fill)
      ..restore();
  }

  void _zig(Canvas c, Offset from, Offset to, double w, Color color, double a) {
    _path
      ..reset()
      ..moveTo(from.dx, from.dy);
    for (var k = 1; k < 4; k++) {
      final p = Offset.lerp(from, to, k / 4)! + Offset((k.isEven ? 1 : -1) * w * 1.6, 0);
      _path.lineTo(p.dx, p.dy);
    }
    _path.lineTo(to.dx, to.dy);
    _line
      ..strokeWidth = w
      ..color = color.withValues(alpha: a);
    c.drawPath(_path, _line);
  }
}
