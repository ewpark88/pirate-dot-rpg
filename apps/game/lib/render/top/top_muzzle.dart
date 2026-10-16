import 'dart:math' as math;
import 'dart:ui';

/// 발사 임팩트 (사용자 '폭탄을 쏠 때 임팩트가 없다'): 포구 섬광(등급 색 테 + 흰 중심 80ms)·작은 고리·연기 퍼프. TopHits에서 뺌.
class TopMuzzle {
  final List<_Muzzle> _muzzles = [];
  final Map<String, double> _lastMuzzle = {};
  static const _muzzleGapMs = 140.0;

  /// 발사 임팩트 (사용자 '폭탄을 쏠 때 임팩트가 없다'): 포구([x],[y], 쏘는 방향 [angle]) 섬광(등급 색 [color] 테 + 흰 중심 80ms)·작은 고리·연기 퍼프.
  /// 같은 선원은 [_muzzleGapMs]마다 한 번(동시 발사가 많아도 화면이 하얘지지 않게). [atMs] = 실제 발사 시각(장면 ms).
  void muzzle(double x, double y, double angle, int color, String crewId, double atMs) {
    final last = _lastMuzzle[crewId];
    if (last != null && atMs - last < _muzzleGapMs) return;
    _lastMuzzle[crewId] = atMs;
    if (_muzzles.length >= 16) _muzzles.removeAt(0);
    _muzzles.add(_Muzzle(x + math.cos(angle) * 6, y + math.sin(angle) * 6, atMs, angle, color));
  }

  void paint(Canvas c, double now, {required bool flash, required bool powerSave}) {
    _muzzles.removeWhere((m) => now - m.ms >= 450);
    for (final m in _muzzles) {
      final age = now - m.ms;
      if (age < 0) continue;
      final at = Offset(m.x, m.y);
      if (!powerSave) {
        for (var k = 0; k < 3; k++) {
          final t = age / 450;
          final a = m.angle + (k - 1) * 0.7;
          final d = 3 + 7 * t;
          _paint.color = Color.fromRGBO(220, 220, 228, 0.55 * (1 - t));
          c.drawCircle(at + Offset(math.cos(a) * d, math.sin(a) * d), 1.5 + 2.5 * t, _paint);
        }
      }
      if (age < 250) {
        final t = age / 250;
        _ring
          ..strokeWidth = 1
          ..color = Color(m.color).withValues(alpha: 0.8 * (1 - t));
        c.drawCircle(at, 3 + 8 * t, _ring);
      }
      if (age < 80 && flash) {
        _ring
          ..strokeWidth = 1.5
          ..color = Color(m.color);
        c.drawCircle(at, 4.5, _ring);
        _paint.color = Color.lerp(Color(m.color), const Color(0xFFFFFFFF), 0.35)!; // 흰 대신 등급 색
        c.drawCircle(at, 3, _paint);
      }
    }
  }

  final _paint = Paint()..isAntiAlias = false;
  final _ring = Paint()..style = PaintingStyle.stroke;

  void clear() {
    _muzzles.clear();
    _lastMuzzle.clear();
  }
}

class _Muzzle {
  _Muzzle(this.x, this.y, this.ms, this.angle, this.color);
  final double x;
  final double y;
  final double ms;
  final double angle;
  final int color;
}
