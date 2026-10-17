import 'dart:math' as math;
import 'dart:ui';

/// 솟아오르기 예고(EnemyEmerging): 물 밑 그림자·끓는 거품 고리 → 물보라 터짐. 전장 좌표.
class TopEmerge {
  final List<_Emerge> _emerges = [];
  final _paint = Paint()..isAntiAlias = false;
  final _ring = Paint()..style = PaintingStyle.stroke;

  /// 솟아오르기 예고(EnemyEmerging): ([x],[y])에 [warnMs] 동안 그림자·끓는 물보라, 끝나면 물보라 터짐.
  void add(double x, double y, double startMs, double warnMs) {
    if (_emerges.length >= 16) _emerges.removeAt(0);
    _emerges.add(_Emerge(x, y, startMs, warnMs));
  }

  void paint(Canvas c, double now) {
    _emerges.removeWhere((m) => now - m.ms > m.warnMs + 350);
    for (final m in _emerges) {
      final age = now - m.ms;
      if (age < 0) continue;
      final at = Offset(m.x, m.y);
      if (age < m.warnMs) {
        final t = age / m.warnMs;
        // 물 밑 그림자(점점 진해짐) + 끓는 거품 고리(맥박) + 올라오는 거품
        _paint.color = Color.fromRGBO(10, 30, 60, 0.15 + 0.3 * t);
        c.drawOval(Rect.fromCenter(center: at, width: 10 + 6 * t, height: 7 + 4 * t), _paint);
        final pulse = 0.5 + 0.5 * math.sin(age / 60);
        _ring
          ..strokeWidth = 1.5
          ..color = Color.fromRGBO(240, 250, 255, 0.5 + 0.4 * pulse);
        c.drawCircle(at, 6 + 4 * t + pulse, _ring);
        for (var k = 0; k < 6; k++) {
          final a = k * math.pi / 3 + age / 300;
          final r = 3 + ((age / 90 + k) % 5);
          _paint.color = const Color(0xFFF2FBFF).withValues(alpha: 0.8);
          c.drawRect(Rect.fromLTWH(at.dx + math.cos(a) * r, at.dy + math.sin(a) * r, 1.5, 1.5), _paint);
        }
        continue;
      }
      // 터짐: 흰 물방울이 둥글게 튀고 고리가 퍼진다
      final t = (age - m.warnMs) / 350;
      _ring
        ..strokeWidth = 2
        ..color = Color.fromRGBO(255, 255, 255, 1 - t);
      c.drawCircle(at, 6 + 14 * t, _ring);
      for (var k = 0; k < 10; k++) {
        final a = k * math.pi / 5 + 0.3;
        final d = 4 + 16 * t;
        _paint.color = Color.fromRGBO(220, 240, 255, 1 - t);
        c.drawRect(Rect.fromLTWH(at.dx + math.cos(a) * d, at.dy + math.sin(a) * d - 6 * t * (1 - t) * 4, 2, 2), _paint);
      }
    }
  }

  void clear() => _emerges.clear();
}

class _Emerge {
  _Emerge(this.x, this.y, this.ms, this.warnMs);
  final double x;
  final double y;
  final double ms;
  final double warnMs;
}
