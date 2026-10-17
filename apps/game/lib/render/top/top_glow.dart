import 'dart:math' as math;
import 'dart:ui';

/// 디자인 개편 ③ 발광(쿵푸할매식 마법진): 선원 스킬을 쓰면 배 밑에 빛나는 마법진이 펼쳐졌다(0.2초) 돌며(0.6초) 사라진다(0.3초).
/// 두 겹 고리 + 육각별 + 고리 사이 룬 눈금, 바깥은 두꺼운 반투명 선을 겹쳐 번지는 빛. 색 = 스킬 쓴 선원 계열 색. 전장 좌표(배를 따라감).
class TopGlow {
  final List<_Circle> _circles = [];
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final _star = Path();

  static const _openMs = 200.0;
  static const _holdMs = 600.0;
  static const _closeMs = 300.0;
  static const _max = 3;

  /// 배 밑 마법진(반지름 [r], 색 [color]).
  void circle(double now, double r, int color) {
    if (_circles.length >= _max) _circles.removeAt(0);
    _circles.add(_Circle(now, r, color));
  }

  void clear() => _circles.clear();

  /// 배([ship]) 밑 — 적보다 먼저 그린다. [lite]면 번지는 빛 겹을 뺀다.
  void paint(Canvas c, double now, Offset ship, {required bool lite}) {
    _circles.removeWhere((m) => now - m.at > _openMs + _holdMs + _closeMs);
    for (final m in _circles) {
      final age = now - m.at;
      final open = math.min<double>(1, age / _openMs);
      final fade = age > _openMs + _holdMs ? 1 - (age - _openMs - _holdMs) / _closeMs : 1.0;
      final r = m.r * (0.4 + 0.6 * (1 - (1 - open) * (1 - open)));
      final rot = age / 900;
      final col = Color(m.color);
      if (!lite) {
        for (final (w, a) in const [(9.0, 0.12), (5.0, 0.22)]) {
          _line
            ..strokeWidth = w
            ..color = col.withValues(alpha: a * fade);
          c.drawCircle(ship, r, _line);
        }
      }
      _line
        ..strokeWidth = 1.6
        ..color = col.withValues(alpha: 0.95 * fade);
      c
        ..drawCircle(ship, r, _line)
        ..drawCircle(ship, r * 0.78, _line);
      // 육각별(두 삼각) — 천천히 돈다
      _star.reset();
      for (var tri = 0; tri < 2; tri++) {
        for (var k = 0; k <= 3; k++) {
          final a = rot + tri * math.pi / 3 + k * 2 * math.pi / 3;
          final p = ship + Offset(math.cos(a), math.sin(a)) * r * 0.78;
          k == 0 ? _star.moveTo(p.dx, p.dy) : _star.lineTo(p.dx, p.dy);
        }
      }
      _line
        ..strokeWidth = 1.2
        ..color = col.withValues(alpha: 0.45 * fade); // 배 위를 지나가므로 옅게
      c.drawPath(_star, _line);
      // 룬 눈금: 고리 사이 짧은 줄 12개(반대로 돈다)
      _line.color = const Color(0xFFFFFFFF).withValues(alpha: 0.7 * fade);
      for (var k = 0; k < 12; k++) {
        final a = -rot * 1.5 + k * math.pi / 6;
        final d = Offset(math.cos(a), math.sin(a));
        c.drawLine(ship + d * r * 0.82, ship + d * r * (k.isEven ? 0.95 : 0.9), _line);
      }
    }
  }
}

class _Circle {
  _Circle(this.at, this.r, this.color);
  final double at;
  final double r;
  final int color;
}
