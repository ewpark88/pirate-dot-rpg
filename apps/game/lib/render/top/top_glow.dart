import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/top/top_label.dart';

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

  /// 부위 마일스톤(S2 — 8레벨마다 효과 ×2, '튄다' 대신 그 순간을 크게): 배에서 솟는 금빛 빛기둥 + 금 고리 2겹 + 큰 '×2!'.
  double milestoneAt = -1000000000;
  static const _mileMs = 1400.0;
  final _label = TopLabel();

  void _milestone(Canvas c, double now, Offset ship) {
    final age = now - milestoneAt;
    if (age < 0 || age > _mileMs) return;
    final t = age / _mileMs;
    final rise = math.min<double>(1, t * 4);
    final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    for (final (w, col) in const [(70.0, 0xFFFFC23A), (40.0, 0xFFFFE89A), (16.0, 0xFFFFFFFF)]) {
      final rect = Rect.fromLTRB(ship.dx - w / 2, ship.dy - 260 * rise, ship.dx + w / 2, ship.dy + 10);
      _fill.shader = Gradient.linear(rect.bottomCenter, rect.topCenter, [
        Color(col).withValues(alpha: 0.6 * fade),
        Color(col).withValues(alpha: 0),
      ]);
      c.drawRect(rect, _fill);
    }
    _fill.shader = null;
    for (var k = 0; k < 2; k++) {
      final u = (t * 1.6 - k * 0.25).clamp(0.0, 1.0);
      _line
        ..strokeWidth = 4 * (1 - u) + 1
        ..color = const Color(0xFFFFD45A).withValues(alpha: (1 - u) * fade);
      c.drawCircle(ship, 20 + 70 * u, _line);
    }
    final pop = t < 0.15 ? 0.5 + 0.7 * t / 0.15 : (t < 0.25 ? 1.2 - 0.2 * (t - 0.15) / 0.1 : 1.0);
    _label.draw(c, '×2!', ship + Offset(0, -62 - 18 * rise), 26 * pop, alpha: fade);
  }

  void clear() {
    milestoneAt = -1000000000;
    _circles.clear();
    bossRiseAt = -1000000000;
  }

  /// 보스 등장 시각(장면 ms) — Moments.onBossSpawned가 넣는다. 그 자리에서 붉은·보라 빛기둥이 솟는다(이름 리본은 UI).
  double bossRiseAt = -1000000000;
  final _fill = Paint()..isAntiAlias = true;
  static const _bossMs = 1100.0;

  /// 보스 자리 [at](반지름 [r]) 빛기둥 — TopMarks가 보스 체력 막대 전에 부른다.
  void paintBoss(Canvas c, double now, Offset at, double r) {
    final age = now - bossRiseAt;
    if (age < 0 || age > _bossMs) return;
    final t = age / _bossMs;
    final rise = math.min<double>(1, t * 3);
    final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    final h = 220 * rise;
    for (final (w, col) in const [(2.2, 0xFFB43AFF), (1.4, 0xFFFF3A5A), (0.6, 0xFFFFE6F0)]) {
      final rect = Rect.fromLTRB(at.dx - r * w * 0.5, at.dy - h, at.dx + r * w * 0.5, at.dy + r * 0.3);
      _fill.shader = Gradient.linear(rect.bottomCenter, rect.topCenter, [
        Color(col).withValues(alpha: 0.55 * fade),
        Color(col).withValues(alpha: 0),
      ]);
      c.drawRect(rect, _fill);
    }
    _fill.shader = null;
    // 바다 위 고리 두 겹
    for (var k = 0; k < 2; k++) {
      final u = ((t * 2) - k * 0.3).clamp(0.0, 1.0);
      _line
        ..strokeWidth = 3 * (1 - u) + 1
        ..color = const Color(0xFFFF5AA0).withValues(alpha: (1 - u) * fade);
      c.drawOval(Rect.fromCenter(center: at, width: r * (1.2 + 2.2 * u), height: r * (0.6 + 1.1 * u)), _line);
    }
  }

  /// 배([ship]) 밑 — 적보다 먼저 그린다. [lite]면 번지는 빛 겹을 뺀다.
  void paint(Canvas c, double now, Offset ship, {required bool lite}) {
    _milestone(c, now, ship);
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
