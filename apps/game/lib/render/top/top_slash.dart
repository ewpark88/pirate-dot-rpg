import 'dart:math' as math;
import 'dart:ui';

/// 탑다운 강습(assault — 상어·꽃게·킹크랩·가재·데비) 근접 연출 (사용자 '가재가 공격을 안 한다?', S1):
/// 강습 선원은 무기 그림이 없어 옆모습 갈고리(배 뱃머리 옆모습 좌표)로 그려져 탑다운에서 안 보였다.
/// 피해가 들어가는 순간 배에서 대상 쪽으로 휘두르는 호(흰 + 등급 색, 0.2초) + 맞은 자리 X자 베기 자국·물방울.
class TopSlash {
  final List<_Swing> _swings = [];
  final _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _paint = Paint()..isAntiAlias = false;
  static const _swingMs = 200.0;
  static const _markMs = 380.0;
  static const _max = 24;

  /// 배([shipX],[shipY])에서 대상([x],[y]) 쪽으로 [atMs]에 휘두름. [color] = 등급 색.
  void swing(double shipX, double shipY, double x, double y, double atMs, int color) {
    if (_swings.length >= _max) _swings.removeAt(0);
    _swings.add(_Swing(shipX, shipY, x, y, atMs, color));
  }

  void clear() => _swings.clear();

  /// 전장 좌표.
  void paint(Canvas c, double now) {
    _swings.removeWhere((s) => now - s.ms > _markMs);
    for (final s in _swings) {
      final age = now - s.ms;
      if (age < 0) continue;
      final dx = s.x - s.sx;
      final dy = s.y - s.sy;
      final dist = math.max<double>(14, math.sqrt(dx * dx + dy * dy));
      final ang = math.atan2(dy, dx);
      final col = Color(s.color);
      if (age < _swingMs) {
        // 휘두름: 대상 방향 ±0.6rad 부채꼴을 따라 앞쪽 끝이 지나가고, 뒤로 꼬리가 남는다.
        final t = age / _swingMs;
        final rect = Rect.fromCircle(center: Offset(s.sx, s.sy), radius: dist);
        final start = ang - 0.6;
        final sweep = 1.2 * t;
        _arc
          ..strokeWidth = 6
          ..color = col.withValues(alpha: 0.55 * (1 - t * 0.5));
        c.drawArc(rect, start, sweep, false, _arc);
        _arc
          ..strokeWidth = 2.5
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95);
        c.drawArc(rect, start + sweep * 0.4, sweep * 0.6, false, _arc);
      }
      // 맞은 자리: X자 베기 자국(흰·등급 색) + 튀는 물방울
      final k = (age / _markMs).clamp(0.0, 1.0);
      final fade = 1 - k;
      final at = Offset(s.x, s.y);
      final len = 5 + 3 * k;
      _arc
        ..strokeWidth = 2
        ..color = col.withValues(alpha: fade);
      c
        ..drawLine(at + Offset(-len, -len), at + Offset(len, len), _arc)
        ..drawLine(at + Offset(len, -len), at + Offset(-len, len), _arc);
      _arc
        ..strokeWidth = 1
        ..color = const Color(0xFFFFFFFF).withValues(alpha: fade);
      c
        ..drawLine(at + Offset(-len, -len), at + Offset(len, len), _arc)
        ..drawLine(at + Offset(len, -len), at + Offset(-len, len), _arc);
      for (var i = 0; i < 6; i++) {
        final a = ang + (i - 2.5) * 0.45;
        final d = 3 + 10 * k;
        _paint.color = const Color(0xFFDDF2FF).withValues(alpha: fade);
        c.drawRect(Rect.fromLTWH(at.dx + math.cos(a) * d, at.dy + math.sin(a) * d - 4 * k * (1 - k), 1.5, 1.5), _paint);
      }
    }
  }
}

class _Swing {
  _Swing(this.sx, this.sy, this.x, this.y, this.ms, this.color);
  final double sx;
  final double sy;
  final double x;
  final double y;
  final double ms;
  final int color;
}
