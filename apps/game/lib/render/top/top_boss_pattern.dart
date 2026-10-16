import 'dart:math' as math;
import 'dart:ui';

/// 탑다운 보스 행동 v2 연출 (S5 BossPatternShown, docs/specs/platform-boss-patterns.md, S1):
/// - volley 예고: 보스에서 배 쪽 부채꼴 빨간 예고선 count줄(약 50°) — 예고가 끝날수록 진해진다. 탄은 EnemyFired(boss_shell)가 그린다.
/// - charge 예고: 보스 → 배 빨간 화살(꺾쇠가 배 쪽으로 흐름) + 보스 둘레 깜빡이는 고리. 동작: 출발 자리부터 지금 보스까지 돌진 자국.
/// - summon 예고: 보스 둘레 count개 물보라 고리가 끓어오름.
/// - blast 예고: 배 둘레 반지름 radius 빨간 원이 안쪽부터 차오르며 점점 빨리 깜빡임. 동작: 큰 붉은 폭발 고리.
/// - cancel(예고 중 기절): 예고를 지운다.
class TopBossPattern {
  final List<_Pattern> _items = [];
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _fill = Paint();
  static const _red = Color(0xFFFF3A2A);
  static const _actMs = 700.0;

  /// 예고 시작.
  void warn(
    int id,
    String kind,
    double x,
    double y,
    double angle,
    int count,
    double radius,
    double startMs,
    double warnMs,
  ) {
    _items
      ..removeWhere((p) => p.id == id)
      ..add(_Pattern(id, kind, x, y, angle, count, radius, startMs, warnMs));
  }

  /// 동작 시작(예고 끝).
  void act(int id, double nowMs) {
    for (final p in _items) {
      if (p.id == id) p.actMs = nowMs;
    }
  }

  /// 예고 취소(기절).
  void cancel(int id) => _items.removeWhere((p) => p.id == id);

  /// 돌진이 막 닿는 중인가(배 피격에 큰 흔들림을 얹을지).
  bool charging(double nowMs) => _items.any((p) => p.kind == 'charge' && p.actMs != null && nowMs - p.actMs! < _actMs);

  void clear() => _items.clear();

  /// 전장 좌표. [ship] = 배 중심, [bossAt] = 지금 보스 자리(돌진 자국용, 없으면 null).
  void paint(Canvas c, double now, Offset ship, Offset? Function(int id) bossAt, {required bool flash}) {
    _items.removeWhere((p) => now - p.startMs > p.warnMs + _actMs * 1.5);
    for (final p in _items) {
      final age = now - p.startMs;
      if (age < 0) continue;
      final boss = Offset(p.x, p.y);
      final acting = p.actMs != null;
      final t = (age / p.warnMs).clamp(0.0, 1.0);
      switch (p.kind) {
        case 'volley' when !acting:
          final toShip = (ship - boss).distance + 30;
          const spread = 50 * math.pi / 180;
          final n = math.max(1, p.count);
          for (var i = 0; i < n; i++) {
            final a = n == 1 ? p.angle : p.angle - spread / 2 + spread * i / (n - 1);
            _line
              ..strokeWidth = 1 + 1.5 * t
              ..color = _red.withValues(alpha: 0.25 + 0.6 * t);
            _dashed(c, boss, boss + Offset(math.cos(a), math.sin(a)) * toShip, 5, 4);
          }
        case 'charge':
          if (!acting) {
            _arrow(c, boss, ship, t, now);
            final pulse = 0.5 + 0.5 * math.sin(now / 50);
            _line
              ..strokeWidth = 2
              ..color = _red.withValues(alpha: 0.4 + 0.5 * pulse);
            c.drawCircle(boss, 16 + 3 * pulse, _line);
          } else {
            final cur = bossAt(p.id);
            if (cur != null) {
              final k = ((now - p.actMs!) / _actMs).clamp(0.0, 1.0);
              _line
                ..strokeWidth = 10 * (1 - k)
                ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * (1 - k));
              c.drawLine(boss, cur, _line);
              _line
                ..strokeWidth = 4 * (1 - k)
                ..color = _red.withValues(alpha: 0.6 * (1 - k));
              c.drawLine(boss, cur, _line);
            }
          }
        case 'summon' when !acting:
          final n = math.max(1, p.count);
          for (var i = 0; i < n; i++) {
            final a = i * 2 * math.pi / n + p.angle;
            final at = boss + Offset(math.cos(a), math.sin(a)) * 30;
            final pulse = 0.5 + 0.5 * math.sin(now / 70 + i);
            _line
              ..strokeWidth = 1.5
              ..color = Color.fromRGBO(240, 250, 255, 0.4 + 0.5 * pulse * t);
            c.drawCircle(at, 4 + 5 * t + pulse, _line);
            _fill.color = Color.fromRGBO(10, 30, 60, 0.15 + 0.3 * t);
            c.drawOval(Rect.fromCenter(center: at, width: 10 * t + 4, height: 7 * t + 3), _fill);
          }
        case 'blast':
          if (!acting) {
            // 점점 빨리 깜빡임: 주기 400ms → 80ms
            final period = 400 - 320 * t;
            final on = !flash || (age / period).floor().isEven;
            _fill.color = _red.withValues(alpha: (on ? 0.22 : 0.1) * (0.4 + 0.6 * t));
            c.drawCircle(ship, p.radius * t, _fill);
            _line
              ..strokeWidth = 2
              ..color = _red.withValues(alpha: on ? 0.95 : 0.5);
            c.drawCircle(ship, p.radius, _line);
          } else {
            final k = ((now - p.actMs!) / _actMs).clamp(0.0, 1.0);
            if (flash && k < 0.15) {
              _fill.color = const Color(0xFFFFFFFF).withValues(alpha: 0.8 * (1 - k / 0.15));
              c.drawCircle(ship, p.radius, _fill);
            }
            _fill.color = Color.lerp(const Color(0xFFFFB33A), _red, k)!.withValues(alpha: 0.6 * (1 - k));
            c.drawCircle(ship, p.radius * (0.6 + 0.6 * k), _fill);
            _line
              ..strokeWidth = 4 * (1 - k) + 1
              ..color = _red.withValues(alpha: 1 - k);
            c.drawCircle(ship, p.radius * (1 + 0.5 * k), _line);
          }
        default:
      }
    }
  }

  /// 보스 → 배 빨간 화살: 굵은 반투명 길 + 배 쪽으로 흐르는 꺾쇠.
  void _arrow(Canvas c, Offset from, Offset to, double t, double now) {
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final u = d / len;
    final nrm = Offset(-u.dy, u.dx);
    _line
      ..strokeWidth = 8
      ..color = _red.withValues(alpha: 0.15 + 0.25 * t);
    c.drawLine(from, to, _line);
    _line
      ..strokeWidth = 2
      ..color = _red.withValues(alpha: 0.5 + 0.5 * t);
    for (var s = (now / 6) % 14; s < len - 6; s += 14) {
      final tip = from + u * s;
      c
        ..drawLine(tip - u * 5 + nrm * 4, tip, _line)
        ..drawLine(tip - u * 5 - nrm * 4, tip, _line);
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, double on, double off) {
    final d = b - a;
    final len = d.distance;
    if (len < 1) return;
    final u = d / len;
    for (var s = 0.0; s < len; s += on + off) {
      c.drawLine(a + u * s, a + u * math.min(len, s + on), _line);
    }
  }
}

class _Pattern {
  _Pattern(this.id, this.kind, this.x, this.y, this.angle, this.count, this.radius, this.startMs, this.warnMs);
  final int id;
  final String kind;
  final double x;
  final double y;
  final double angle;
  final int count;
  final double radius;
  final double startMs;
  final double warnMs;
  double? actMs;
}
