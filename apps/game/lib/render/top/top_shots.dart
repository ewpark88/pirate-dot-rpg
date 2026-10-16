import 'dart:math' as math;
import 'dart:ui';

/// 탑다운 적 포탄 (사용자 '보스가 폭탄도 안 쏜다' — 엔진 BossFired를 렌더가 안 그렸다, S1·S5):
/// 쏜 자리 → 배로 포물선(그림자 + 높이), 크고 어두운 포탄에 보스 색 빛 테·불 꼬리, 닿으면 색 고리·불덩이·파편 폭발.
/// 엔진 피해 시각(ShipDamaged)에 맞춰 닿도록 부르는 쪽이 [fire]의 시작·비행 시간을 앞당겨 준다. 원거리 적 탄(EnemyFired)도 같은 길로.
class TopShots {
  final List<_Shot> _shots = [];
  final _paint = Paint()..isAntiAlias = false;
  final _ring = Paint()..style = PaintingStyle.stroke;
  static const _max = 24;
  static const _boomMs = 360.0;

  /// 한 발: ([fromX],[fromY]) → ([toX],[toY]), 장면 시각 [startMs]부터 [flightMs] 동안. [color] = 빛 테·꼬리·폭발 색, [big] = 보스 포탄.
  void fire(
    double fromX,
    double fromY,
    double toX,
    double toY,
    double startMs,
    double flightMs,
    int color, {
    bool big = true,
  }) {
    if (_shots.length >= _max) _shots.removeAt(0);
    _shots.add(_Shot(fromX, fromY, toX, toY, startMs, math.max(1, flightMs), color, big: big));
  }

  void clear() => _shots.clear();

  /// 전장 좌표. [flash] 꺼짐이면 폭발 흰 번쩍만 뺀다.
  void paint(Canvas c, double now, {required bool flash}) {
    _shots.removeWhere((s) => now - s.startMs > s.flightMs + _boomMs);
    for (final s in _shots) {
      final age = now - s.startMs;
      if (age < 0) continue;
      final col = Color(s.color);
      final r = s.big ? 7.5 : 3.0;
      // 빛 테 색: 보스 색이 어두우면(유령선 등) 위협적인 빨강 쪽으로.
      final rim = s.big ? Color.lerp(col, const Color(0xFFFF3A2A), 0.45)! : col;
      if (age < s.flightMs) {
        final t = age / s.flightMs;
        final x = s.fromX + (s.toX - s.fromX) * t;
        final gy = s.fromY + (s.toY - s.fromY) * t;
        final h = (s.big ? 22 : 10) * 4 * t * (1 - t);
        // 그림자(높을수록 작고 흐림)
        _paint.color = Color.fromRGBO(20, 24, 40, 0.35 - 0.15 * t * (1 - t) * 4);
        c.drawOval(
          Rect.fromCenter(center: Offset(x, gy), width: r * 2 * (1 - 0.3 * h / 22), height: r * (1 - 0.3 * h / 22)),
          _paint,
        );
        final y = gy - h * 0.5;
        // 불 꼬리: 날아온 쪽으로 5개, 보스 색 → 주황
        for (var k = 5; k >= 1; k--) {
          final tk = math.max(0, t - k * 0.035);
          final kx = s.fromX + (s.toX - s.fromX) * tk;
          final ky = s.fromY + (s.toY - s.fromY) * tk - (s.big ? 22 : 10) * 4 * tk * (1 - tk) * 0.5;
          _paint.color = (s.big ? Color.lerp(rim, const Color(0xFFFF8A2A), k / 5)! : col).withValues(
            alpha: 0.75 - k * 0.12,
          );
          c.drawCircle(Offset(kx, ky), r * (1 - k * 0.13), _paint);
        }
        // 위협 빛무리(보스 포탄만)
        if (s.big) {
          _paint.color = rim.withValues(alpha: 0.3 + 0.15 * math.sin(age / 40));
          c.drawCircle(Offset(x, y), r + 5, _paint);
        }
        // 포탄: 어두운 몸 + 보스 색 빛 테 + 흰 하이라이트
        _ring
          ..strokeWidth = s.big ? 2.5 : 1
          ..color = rim;
        c.drawCircle(Offset(x, y), r + 1, _ring);
        _paint.color = s.big ? const Color(0xFF1E1A26) : col;
        c.drawCircle(Offset(x, y), r, _paint);
        _paint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.8);
        c.drawCircle(Offset(x - r * 0.35, y - r * 0.35), r * 0.3, _paint);
        continue;
      }
      // 폭발: 색 고리 + 불덩이 + 파편
      final t = (age - s.flightMs) / _boomMs;
      final at = Offset(s.toX, s.toY);
      final size = s.big ? 1.0 : 0.6;
      if (flash && t < 0.2) {
        _paint.color = const Color(0xFFFFFFFF).withValues(alpha: 1 - t / 0.2);
        c.drawCircle(at, 9 * size, _paint);
      }
      _paint.color = Color.lerp(const Color(0xFFFFD84A), const Color(0xFFFF5A2A), t)!.withValues(alpha: 0.9 * (1 - t));
      c.drawCircle(at, (5 + 8 * t) * size, _paint);
      _ring
        ..strokeWidth = 2
        ..color = col.withValues(alpha: 1 - t);
      c.drawCircle(at, (6 + 16 * t) * size, _ring);
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3 + 0.4;
        final d = (4 + 14 * t) * size;
        _paint.color = const Color(0xFF3A3040).withValues(alpha: 1 - t);
        c.drawRect(Rect.fromLTWH(at.dx + math.cos(a) * d, at.dy + math.sin(a) * d, 2, 2), _paint);
      }
    }
  }
}

class _Shot {
  _Shot(this.fromX, this.fromY, this.toX, this.toY, this.startMs, this.flightMs, this.color, {required this.big});
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final double startMs;
  final double flightMs;
  final int color;
  final bool big;
}
