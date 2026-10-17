import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/top/top_label.dart';

/// 탑다운 보스 행동 연출 (BossPatternShown, docs/specs/platform-boss-patterns.md · S2 boss-dodge 회피):
/// 예고는 '어디가 위험한지' 확실하게 — 조준 자리는 예고 시작 때 배 자리로 고정(엔진 BossPlan.aim과 같다, 배가 비키면 빗나감).
/// - volley: 보스 → 조준 자리 붉은 부채꼴(채움 + 테, spreadDeg) — 예고가 끝날수록 진해짐. 탄은 EnemyFired가 그린다.
/// - charge: 보스 → 조준 방향 화살 띠(조준 너머까지, 꺾쇠가 흐름). 동작: 돌진 자국.
/// - blast: 조준 자리 원 장판 — 테두리 점멸(점점 빨리)·안쪽이 차오름. 동작: 붉은 폭발 고리.
/// - summon: 보스 둘레 물보라 고리.
/// - 모든 예고: 보스 머리 위 시간 막대(채워지면 공격). homing(피할 수 없음)이면 배에 붉은 조준 표시가 돈다.
/// - 빗나감(BossAttackMissed): 배 옆 'MISS!' 큰 글자.
/// 채움은 반투명 50% 이하(적을 가리지 않게).
class TopBossPattern {
  final List<_Pattern> _items = [];
  final List<(Offset, double)> _misses = [];
  final _label = TopLabel();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _fill = Paint();
  static const _red = Color(0xFFFF3A2A);
  static const _actMs = 700.0;
  static const _missMs = 800.0;

  /// 예고 시작: [aim] = 그 순간 배 자리(조준 고정), [spreadDeg] = 탄막 부채꼴 폭, [homing] = 피할 수 없음.
  void warn(
    int id,
    String kind,
    double x,
    double y,
    double angle,
    int count,
    double radius,
    double startMs,
    double warnMs, {
    Offset? aim,
    double spreadDeg = 50,
    bool homing = false,
  }) {
    _items
      ..removeWhere((p) => p.id == id)
      ..add(_Pattern(id, kind, x, y, angle, count, radius, startMs, warnMs, aim, spreadDeg, homing: homing));
  }

  /// 동작 시작(예고 끝).
  void act(int id, double nowMs) {
    for (final p in _items) {
      if (p.id == id) p.actMs = nowMs;
    }
  }

  /// 예고 취소(브레이크).
  void cancel(int id) => _items.removeWhere((p) => p.id == id);

  /// 빗나감: 배 옆 'MISS!'.
  void miss(Offset ship, double now) {
    if (_misses.length >= 4) _misses.removeAt(0);
    _misses.add((ship, now));
  }

  /// 돌진이 막 닿는 중인가(배 피격에 큰 흔들림을 얹을지).
  bool charging(double nowMs) => _items.any((p) => p.kind == 'charge' && p.actMs != null && nowMs - p.actMs! < _actMs);

  void clear() {
    _items.clear();
    _misses.clear();
  }

  /// 전장 좌표. [ship] = 배 중심, [bossAt] = 지금 보스 자리(돌진 자국·시간 막대).
  void paint(Canvas c, double now, Offset ship, Offset? Function(int id) bossAt, {required bool flash}) {
    _items.removeWhere((p) => now - p.startMs > p.warnMs + _actMs * 1.5);
    for (final p in _items) {
      final age = now - p.startMs;
      if (age < 0) continue;
      final boss = Offset(p.x, p.y);
      final aim = p.aim ?? ship;
      final acting = p.actMs != null;
      final t = (age / p.warnMs).clamp(0.0, 1.0);
      if (!acting) _timeBar(c, bossAt(p.id) ?? boss, t);
      if (p.homing && !acting) _crosshair(c, ship, now, t);
      switch (p.kind) {
        case 'volley' when !acting:
          _fan(c, boss, aim, p.spreadDeg, t);
        case 'charge':
          if (!acting) {
            final d = aim - boss;
            _arrow(c, boss, boss + d * 1.3, t, now); // 조준 너머까지 곧게(따라오지 않음)
          } else {
            _trail(c, boss, bossAt(p.id), now - p.actMs!);
          }
        case 'summon' when !acting:
          _summon(c, boss, p, t, now);
        case 'blast':
          if (!acting) {
            _zone(c, aim, p.radius, t, age, flash: flash);
          } else {
            _boom(c, aim, p.radius, ((now - p.actMs!) / _actMs).clamp(0.0, 1.0), flash: flash);
          }
        default:
      }
    }
    _misses.removeWhere((m) => now - m.$2 > _missMs);
    for (final (at, t0) in _misses) {
      final u = (now - t0) / _missMs;
      final pop = u < 0.15 ? 0.7 + 2 * u : 1.0;
      _label.draw(
        c,
        'MISS!',
        at + Offset(26, -18 - 14 * u),
        (16 * pop).roundToDouble(),
        alpha: u < 0.7 ? 1 : (1 - u) / 0.3,
        color: const Color(0xFF5FD8FF),
      );
    }
  }

  /// 붉은 부채꼴(보스 → 조준, 폭 [spreadDeg]): 반투명 채움 + 테.
  void _fan(Canvas c, Offset boss, Offset aim, double spreadDeg, double t) {
    final d = aim - boss;
    final len = d.distance + 30;
    final a = math.atan2(d.dy, d.dx);
    final half = math.max(8, spreadDeg) * math.pi / 360;
    final rect = Rect.fromCircle(center: boss, radius: len);
    final path = Path()
      ..moveTo(boss.dx, boss.dy)
      ..arcTo(rect, a - half, half * 2, false)
      ..close();
    _fill.color = _red.withValues(alpha: 0.12 + 0.3 * t);
    c.drawPath(path, _fill);
    _line
      ..strokeWidth = 1.5 + 1.5 * t
      ..color = _red.withValues(alpha: 0.5 + 0.5 * t);
    c.drawPath(path, _line);
  }

  /// 원 장판: 테두리 점멸(400ms → 80ms)·안쪽 차오름.
  void _zone(Canvas c, Offset at, double radius, double t, double age, {required bool flash}) {
    final period = 400 - 320 * t;
    final on = !flash || (age / period).floor().isEven;
    _fill.color = _red.withValues(alpha: 0.1 + 0.32 * t);
    c.drawCircle(at, radius * t, _fill);
    _line
      ..strokeWidth = on ? 3 : 2
      ..color = _red.withValues(alpha: on ? 0.95 : 0.45);
    c.drawCircle(at, radius, _line);
  }

  void _boom(Canvas c, Offset at, double radius, double k, {required bool flash}) {
    if (flash && k < 0.15) {
      _fill.color = const Color(0xFFFFB33A).withValues(alpha: 0.45 * (1 - k / 0.15));
      c.drawCircle(at, radius, _fill);
    }
    _fill.color = Color.lerp(const Color(0xFFFFB33A), _red, k)!.withValues(alpha: 0.5 * (1 - k));
    c.drawCircle(at, radius * (0.6 + 0.6 * k), _fill);
    _line
      ..strokeWidth = 4 * (1 - k) + 1
      ..color = _red.withValues(alpha: 1 - k);
    c.drawCircle(at, radius * (1 + 0.5 * k), _line);
  }

  /// 예고 시간 막대: 보스 머리 위 붉은 막대가 채워지면 공격.
  void _timeBar(Canvas c, Offset boss, double t) {
    final r = Rect.fromCenter(center: boss + const Offset(0, -46), width: 36, height: 5);
    _fill.color = const Color(0xAA1A1424);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(1.5), const Radius.circular(3)), _fill);
    _fill.color = Color.lerp(const Color(0xFFFFB33A), _red, t)!;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width * t, r.height), const Radius.circular(2)),
      _fill,
    );
  }

  /// 피할 수 없음(homing): 배에 도는 붉은 조준 표시.
  void _crosshair(Canvas c, Offset ship, double now, double t) {
    final r = 26 - 6 * t;
    _line
      ..strokeWidth = 2.5
      ..color = _red.withValues(alpha: 0.6 + 0.4 * t);
    c.drawCircle(ship, r, _line);
    final spin = now / 400;
    for (var i = 0; i < 4; i++) {
      final a = spin + i * math.pi / 2;
      final u = Offset(math.cos(a), math.sin(a));
      c.drawLine(ship + u * (r - 6), ship + u * (r + 7), _line);
    }
  }

  void _summon(Canvas c, Offset boss, _Pattern p, double t, double now) {
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
  }

  void _trail(Canvas c, Offset from, Offset? cur, double ms) {
    if (cur == null) return;
    final k = (ms / _actMs).clamp(0.0, 1.0);
    _line
      ..strokeWidth = 10 * (1 - k)
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * (1 - k));
    c.drawLine(from, cur, _line);
    _line
      ..strokeWidth = 4 * (1 - k)
      ..color = _red.withValues(alpha: 0.6 * (1 - k));
    c.drawLine(from, cur, _line);
  }

  /// 화살 띠: 굵은 반투명 길 + 앞쪽으로 흐르는 꺾쇠.
  void _arrow(Canvas c, Offset from, Offset to, double t, double now) {
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final u = d / len;
    final nrm = Offset(-u.dy, u.dx);
    _line
      ..strokeWidth = 14
      ..color = _red.withValues(alpha: 0.12 + 0.3 * t);
    c.drawLine(from, to, _line);
    _line
      ..strokeWidth = 2.5
      ..color = _red.withValues(alpha: 0.5 + 0.5 * t);
    for (var s = (now / 6) % 14; s < len - 6; s += 14) {
      final tip = from + u * s;
      c
        ..drawLine(tip - u * 6 + nrm * 6, tip, _line)
        ..drawLine(tip - u * 6 - nrm * 6, tip, _line);
    }
  }
}

class _Pattern {
  _Pattern(
    this.id,
    this.kind,
    this.x,
    this.y,
    this.angle,
    this.count,
    this.radius,
    this.startMs,
    this.warnMs,
    this.aim,
    this.spreadDeg, {
    required this.homing,
  });
  final int id;
  final String kind;
  final double x;
  final double y;
  final double angle;
  final int count;
  final double radius;
  final double startMs;
  final double warnMs;
  final Offset? aim;
  final double spreadDeg;
  final bool homing;
  double? actMs;
}
