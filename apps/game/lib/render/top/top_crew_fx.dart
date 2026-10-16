import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/pixel_glyphs.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';

/// 선원 개성 v2 연출 (S5 crew-identity, S1):
/// - 거북(turtle) 보호막: 배 둘레 반투명 육각 껍질(BattleView.shipShield 0~1만큼 진하게), 막이 받은 피격(ShipDamaged 0)은 물결,
///   ShieldUp은 꽃피듯 퍼지는 고리, ShieldBroken은 육각 조각이 튄다.
/// - 펠리(pelly) 낙뢰: 예고 동안 대상 위 먹구름 그림자·예고 원(빛 점) → 굵은 번개 내리꽂힘 + 살짝 번쩍 + 주변 적으로 가는 연쇄 번개.
/// - 빗나감(AttackMissed): 작은 회색 'MISS'가 떠오른다.
/// - 펌펌(pumpum) 피버 서포트: 출전 중 피버 게이지가 차오를 때 배에서 북 소리 파동 고리.
class TopCrewFx {
  final _fill = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static const _shellColor = Color(0xFF7FE0C8);
  static const _bolt = Color(0xFFFFF27A);

  /// 보호막이 켜진·막이 받은·깨진 시각(장면 ms).
  double upAt = -1000000000;
  double rippleAt = -1000000000;
  double brokenAt = -1000000000;
  final List<_Strike> _strikes = [];
  final List<(double, double, double)> _misses = []; // x, y, ms
  final List<double> _drums = [];
  double _lastFever = 0;
  double _lastDrum = -1000000000;

  /// 낙뢰: ([x],[y])에 [startMs]부터 [warnMs] 예고, 그 뒤 내리꽂힘.
  void lightning(double x, double y, double startMs, double warnMs) {
    if (_strikes.length >= 12) _strikes.removeAt(0);
    _strikes.add(_Strike(x, y, startMs, warnMs));
  }

  void miss(double x, double y, double now) {
    if (_misses.length >= 16) _misses.removeAt(0);
    _misses.add((x, y, now));
  }

  /// 피버 게이지가 오르면(펌펌 출전 중) 북 파동 — 350ms마다 한 번.
  void fever(double gauge, {required bool drummer, required double now}) {
    if (drummer && gauge > _lastFever + 1e-9 && now - _lastDrum >= 350) {
      _lastDrum = now;
      _drums.add(now);
    }
    _lastFever = gauge;
  }

  void clear() {
    _strikes.clear();
    _misses.clear();
    _drums.clear();
    upAt = rippleAt = brokenAt = -1000000000;
  }

  /// 전장 좌표. [ship] = 배 중심, [shipR] = 배 반지름(그림), [shield] = 남은 막 0~1, [poses]·[poseCount] = 연쇄 대상.
  void paint(
    Canvas c,
    double now,
    Offset ship,
    double shipR,
    double shield,
    List<EnemyPose> poses,
    int poseCount, {
    required bool flash,
  }) {
    _shield(c, now, ship, shipR + 6, shield);
    _paintStrikes(c, now, poses, poseCount, flash: flash);
    _misses.removeWhere((m) => now - m.$3 > 700);
    for (final (x, y, at) in _misses) {
      final t = (now - at) / 700;
      drawPixelText(c, 'MISS', x - 7, y - 10 - 8 * t, (((1 - t) * 0xCC).round() << 24) | 0xB8C0CC);
    }
    _drums.removeWhere((d) => now - d > 500);
    for (final d in _drums) {
      final t = (now - d) / 500;
      _line
        ..strokeWidth = 2.5 * (1 - t) + 0.5
        ..color = const Color(0xFFFF8A2A).withValues(alpha: 0.8 * (1 - t));
      c.drawCircle(ship, shipR + 4 + 30 * t, _line);
    }
  }

  void _shield(Canvas c, double now, Offset ship, double r, double shield) {
    final up = now - upAt;
    if (up >= 0 && up < 400) {
      final t = up / 400;
      _line
        ..strokeWidth = 3 * (1 - t)
        ..color = _shellColor.withValues(alpha: 1 - t);
      c.drawCircle(ship, r * (0.6 + 0.6 * t), _line);
    }
    final br = now - brokenAt;
    if (br >= 0 && br < 600) {
      final t = br / 600;
      for (var k = 0; k < 10; k++) {
        final a = k * math.pi / 5 + 0.3;
        final at = ship + Offset(math.cos(a), math.sin(a)) * (r + 22 * t);
        _hex(c, at, 3.5, _shellColor.withValues(alpha: 1 - t), fill: true, spin: t * 3 + k);
      }
    }
    if (shield <= 0) return;
    final rip = now - rippleAt;
    final hit = rip >= 0 && rip < 300 ? 1 - rip / 300 : 0.0;
    final a = (0.18 + 0.32 * shield) * (1 + hit);
    _fill.color = _shellColor.withValues(alpha: 0.12 * shield + 0.2 * hit);
    c.drawOval(Rect.fromCenter(center: ship, width: r * 2, height: r * 2.4), _fill);
    // 육각 무늬: 껍질 위 고리 두 줄
    for (var ring = 0; ring < 2; ring++) {
      final rr = r * (0.55 + 0.4 * ring);
      final n = 6 + ring * 6;
      for (var k = 0; k < n; k++) {
        final ang = k * 2 * math.pi / n + now / 4000 * (ring.isEven ? 1 : -1);
        _hex(
          c,
          ship + Offset(math.cos(ang) * rr, math.sin(ang) * rr * 1.2),
          4,
          _shellColor.withValues(alpha: a.clamp(0, 1)),
        );
      }
    }
    _line
      ..strokeWidth = 1.5 + 2 * hit
      ..color = Color.lerp(
        _shellColor,
        const Color(0xFFFFFFFF),
        hit,
      )!.withValues(alpha: (0.5 + 0.4 * shield).clamp(0, 1));
    c.drawOval(Rect.fromCenter(center: ship, width: r * 2, height: r * 2.4), _line);
  }

  final _hexPath = Path();

  void _hex(Canvas c, Offset at, double s, Color color, {bool fill = false, double spin = 0}) {
    _hexPath.reset();
    for (var i = 0; i < 6; i++) {
      final a = spin + i * math.pi / 3;
      final p = at + Offset(math.cos(a), math.sin(a)) * s;
      i == 0 ? _hexPath.moveTo(p.dx, p.dy) : _hexPath.lineTo(p.dx, p.dy);
    }
    _hexPath.close();
    if (fill) {
      _fill.color = color;
      c.drawPath(_hexPath, _fill);
    } else {
      _line
        ..strokeWidth = 1
        ..color = color;
      c.drawPath(_hexPath, _line);
    }
  }

  void _paintStrikes(Canvas c, double now, List<EnemyPose> poses, int poseCount, {required bool flash}) {
    _strikes.removeWhere((s) => now - s.ms > s.warnMs + 450);
    for (final s in _strikes) {
      final age = now - s.ms;
      if (age < 0) continue;
      final at = Offset(s.x, s.y);
      if (age < s.warnMs) {
        // 먹구름 그림자 + 예고 원(빛 점이 모인다)
        final t = age / s.warnMs;
        _fill.color = Color.fromRGBO(20, 24, 40, 0.15 + 0.25 * t);
        c.drawOval(Rect.fromCenter(center: at, width: 26, height: 14), _fill);
        _line
          ..strokeWidth = 1.5
          ..color = _bolt.withValues(alpha: 0.4 + 0.5 * t);
        c.drawCircle(at, 14 - 8 * t, _line);
        continue;
      }
      final t = (age - s.warnMs) / 450;
      if (flash && t < 0.2) {
        _fill.color = const Color(0xFFFFFFFF).withValues(alpha: 0.6 * (1 - t / 0.2));
        c.drawCircle(at, 16, _fill);
      }
      // 굵은 번개: 하늘(위 90)에서 지그재그로
      _zig(c, at + const Offset(0, -90), at, 6, 3.5 * (1 - t) + 1, (1 - t).clamp(0, 1), s.x);
      // 연쇄: 가까운 적 3마리까지 가는 번개
      var n = 0;
      for (var k = 0; k < poseCount && n < 3; k++) {
        final e = poses[k];
        final d = Offset(e.drawX, e.drawY) - at;
        if (d.distance < 4 || d.distance > 45) continue;
        _zig(c, at, Offset(e.drawX, e.drawY), 3, 1.5 * (1 - t) + 0.5, (1 - t).clamp(0, 1), e.id.toDouble());
        n++;
      }
    }
  }

  final _zigPath = Path();

  void _zig(Canvas c, Offset a, Offset b, int segs, double width, double alpha, double seed) {
    final d = b - a;
    final nrm = Offset(-d.dy, d.dx) / math.max(1, d.distance);
    _zigPath
      ..reset()
      ..moveTo(a.dx, a.dy);
    for (var i = 1; i < segs; i++) {
      final f = i / segs;
      final off = ((i * 7 + seed.round()) % 5 - 2) * 3.0;
      final p = a + d * f + nrm * off;
      _zigPath.lineTo(p.dx, p.dy);
    }
    _zigPath.lineTo(b.dx, b.dy);
    _line
      ..strokeWidth = width + 2
      ..color = _bolt.withValues(alpha: 0.35 * alpha);
    c.drawPath(_zigPath, _line);
    _line
      ..strokeWidth = width
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
    c.drawPath(_zigPath, _line);
  }
}

class _Strike {
  _Strike(this.x, this.y, this.ms, this.warnMs);
  final double x;
  final double y;
  final double ms;
  final double warnMs;
}
