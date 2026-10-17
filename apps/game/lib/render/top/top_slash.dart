import 'dart:math' as math;
import 'dart:ui';

/// 탑다운 근접 베기 v2 (사용자 '칼질 모션을 구체적·직관적으로, 등급에 따라 화려하게'): 배에서 대상 쪽으로 초승달 칼 궤적 잔상
/// + 맞은 자리 베임 자국·튀는 파편. 등급별:
/// 일반 흰 얇은 호 1 · 희귀 파랑 2연(엇갈림) · 영웅 보라 3연 + 스파크 · 전설 금빛 큰 호 + 충격파 · 신화 무지개 360° 회전 베기.
class TopSlash {
  final List<_Swing> _swings = [];
  final _fill = Paint()..isAntiAlias = true;
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _paint = Paint()..isAntiAlias = false;
  final _moon = Path();
  static const _swingMs = 200.0;
  static const _spinMs = 280.0;
  static const _comboGapMs = 70.0;
  static const _markMs = 400.0;
  static const _max = 8; // 붐빌 때 초승달이 배 위에 겹겹이 쌓여 회색 덩어리로 보이던 것(탑 실기기)
  static const _rainbow = [0xFFFF5A5A, 0xFFFFB347, 0xFFFFF15A, 0xFF7CF06A, 0xFF5FD8FF, 0xFFB98CFF];

  /// 배([shipX],[shipY])에서 대상([x],[y]) 쪽으로 [atMs]에 휘두름. [color] = 등급 색, [rarity] = 등급 칸(0 일반~4 신화).
  void swing(double shipX, double shipY, double x, double y, double atMs, int color, {int rarity = 0}) {
    if (_swings.length >= _max) _swings.removeAt(0);
    _swings.add(_Swing(shipX, shipY, x, y, atMs, color, rarity.clamp(0, 4)));
  }

  void clear() => _swings.clear();

  /// 전장 좌표.
  void paint(Canvas c, double now) {
    _swings.removeWhere((s) => now - s.ms > _markMs + _comboGapMs * 2);
    for (final s in _swings) {
      final age = now - s.ms;
      if (age < 0) continue;
      final dx = s.x - s.sx;
      final dy = s.y - s.sy;
      final dist = math.max<double>(14, math.sqrt(dx * dx + dy * dy));
      final ang = math.atan2(dy, dx);
      final ship = Offset(s.sx, s.sy);
      final col = Color(s.color);
      if (s.rarity == 4) {
        _spin(c, ship, dist, age);
      } else {
        final strokes = const [1, 2, 3, 1][s.rarity];
        for (var k = 0; k < strokes; k++) {
          final t = (age - k * _comboGapMs) / _swingMs;
          if (t < 0 || t >= 1) continue;
          // 엇갈림: 홀수 번째는 반대 방향으로
          final dir = k.isOdd ? -1.0 : 1.0;
          final big = s.rarity == 3;
          final half = big ? 1.0 : 0.65;
          final r = dist + (big ? 8 : 0);
          final width = big ? 9.0 : 3.0 + s.rarity * 1.5;
          _crescent(c, ship, r, ang - half * dir, 2 * half * dir * _ease(t), width, col, 1 - t * 0.6);
          if (s.rarity == 2) _sparks(c, ship + Offset(math.cos(ang), math.sin(ang)) * r, ang, t, col);
        }
        if (s.rarity == 3) {
          final t = age / _markMs;
          if (t < 1) {
            _line
              ..strokeWidth = 3 * (1 - t) + 1
              ..color = const Color(0xFFFFD84A).withValues(alpha: 1 - t);
            c.drawCircle(Offset(s.x, s.y), 6 + 22 * t, _line);
          }
        }
      }
      _mark(c, Offset(s.x, s.y), ang, age, col, s.rarity);
    }
  }

  /// 초승달 칼 궤적: 바깥 호와 안쪽 호(조금 작은 반지름) 사이를 채워 끝이 뾰족한 잔상. 가운데 흰 심.
  void _crescent(Canvas c, Offset center, double r, double start, double sweep, double width, Color col, double alpha) {
    if (sweep.abs() < 0.02) return;
    final outer = Rect.fromCircle(center: center, radius: r);
    final mid = start + sweep / 2;
    final inner = Rect.fromCircle(
      center: center - Offset(math.cos(mid), math.sin(mid)) * width * 0.5,
      radius: r - width * 0.5,
    );
    _moon
      ..reset()
      ..arcTo(outer, start, sweep, true)
      ..arcTo(inner, start + sweep, -sweep, false)
      ..close();
    _fill.color = col.withValues(alpha: 0.6 * alpha);
    c.drawPath(_moon, _fill);
    _line
      ..strokeWidth = math.max(1.5, width * 0.3)
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
    c.drawArc(outer, start + sweep * 0.35, sweep * 0.65, false, _line);
  }

  /// 신화: 배 둘레 360° 무지개 회전 베기 — 앞쪽 끝이 한 바퀴 돌며 꼬리가 무지개로 남는다.
  void _spin(Canvas c, Offset ship, double dist, double age) {
    final t = age / _spinMs;
    if (t >= 1) return;
    final r = math.max<double>(dist, 30);
    final head = -math.pi / 2 + 2 * math.pi * _ease(t);
    const seg = 0.5;
    for (var k = 0; k < 6; k++) {
      final a = head - (k + 1) * seg;
      if (a < -math.pi / 2) continue;
      _crescent(c, ship, r, a, seg, 10.0 - k, Color(_rainbow[k]), (1 - t * 0.5) * (1 - k * 0.12));
    }
    _line
      ..strokeWidth = 3
      ..color = Color.fromRGBO(255, 255, 255, 1 - t);
    c.drawArc(Rect.fromCircle(center: ship, radius: r), head - 0.4, 0.4, false, _line);
  }

  void _sparks(Canvas c, Offset at, double ang, double t, Color col) {
    _paint.color = col.withValues(alpha: 1 - t);
    for (var i = 0; i < 5; i++) {
      final a = ang + (i - 2) * 0.5;
      final d = 4 + 14 * t;
      c.drawRect(Rect.fromCenter(center: at + Offset(math.cos(a), math.sin(a)) * d, width: 2, height: 2), _paint);
    }
  }

  /// 맞은 자리: 베임 자국(등급 따라 1~3줄 사선, 흰 심) + 튀는 파편.
  void _mark(Canvas c, Offset at, double ang, double age, Color col, int rarity) {
    final k = (age / _markMs).clamp(0.0, 1.0);
    if (k >= 1) return;
    final fade = 1 - k;
    final len = 5 + 2.0 * rarity + 3 * k;
    final cut = ang + math.pi / 2;
    final lines = 1 + math.min(2, rarity);
    for (var i = 0; i < lines; i++) {
      final off = Offset(math.cos(ang), math.sin(ang)) * ((i - (lines - 1) / 2) * 3.5);
      final a = at + off + Offset(math.cos(cut), math.sin(cut)) * -len;
      final b = at + off + Offset(math.cos(cut), math.sin(cut)) * len;
      _line
        ..strokeWidth = 2.5
        ..color = col.withValues(alpha: fade);
      c.drawLine(a, b, _line);
      _line
        ..strokeWidth = 1
        ..color = const Color(0xFFFFFFFF).withValues(alpha: fade);
      c.drawLine(a, b, _line);
    }
    for (var i = 0; i < 6 + rarity * 2; i++) {
      final a = ang + (i - 3) * 0.4;
      final d = 3 + (10 + rarity * 3) * k;
      _paint.color = (i.isEven ? const Color(0xFFFFFFFF) : col).withValues(alpha: fade);
      c.drawRect(Rect.fromLTWH(at.dx + math.cos(a) * d, at.dy + math.sin(a) * d - 4 * k * (1 - k), 1.5, 1.5), _paint);
    }
  }

  static double _ease(double t) => 1 - (1 - t) * (1 - t);
}

class _Swing {
  _Swing(this.sx, this.sy, this.x, this.y, this.ms, this.color, this.rarity);
  final double sx;
  final double sy;
  final double x;
  final double y;
  final double ms;
  final int color;
  final int rarity;
}
