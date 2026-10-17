import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/replay/recording_player.dart';

/// 선원 특성 2차(S5 crew-traits-2) 그림 — TopTraits가 찾아 넣는다. 전장 좌표.
/// - 부메랑(saw): 맞은 자리에서 회전 톱날이 같은 길로 배까지 돌아온다.
/// - 휩쓸기(lobster): 배에서 첫 대상 쪽 부채꼴(deg) 칼바람 섬광.
/// - 물기 속박(bara): 맞은 적 발밑 물 고리 + 이빨 자국, bindSec 동안 따라다닌다.
/// - 관통 가속(sword): 꿰뚫은 순서대로 맞은 자리 섬광이 점점 크고 밝게.
/// - 해적왕 강타(davy): 보스 추가 피해 순간 보스 위 금빛 해골 도장.
class TraitFx2 {
  final List<(Offset, Offset, double)> _saws = []; // 맞은 자리, 배, ms
  final List<(Offset, Offset, double, double, double)> _sweeps = []; // 배, 목표, 반각, 거리, ms
  final Map<int, (double, double)> _binds = {}; // 적 id → (시작, 끝 ms)
  final List<(Offset, int, double)> _pierce = []; // 자리, 순서, ms
  final List<(int, double)> _skulls = []; // 보스 id, ms

  final _fill = Paint()..isAntiAlias = false;
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = false;
  final _path = Path();

  static const _sawMs = 320.0;
  static const _sweepMs = 260.0;
  static const _pierceMs = 260.0;
  static const _skullMs = 600.0;
  static const _skull = ['.yyyy.', 'yyyyyy', 'ykyyky', 'yyyyyy', '.yykyy.', '.y.y.y'];

  void saw(Offset hit, Offset ship, double now) {
    if (_saws.length < 8) _saws.add((hit, ship, now));
  }

  void sweep(Offset ship, Offset target, double deg, double extra, double now) {
    if (_sweeps.length >= 4) _sweeps.removeAt(0);
    _sweeps.add((ship, target, deg * math.pi / 360, (target - ship).distance + extra, now));
  }

  void bind(int id, double sec, double now) {
    if (_binds.length > 40) _binds.removeWhere((_, v) => now > v.$2);
    _binds[id] = (now, now + sec * 1000);
  }

  void pierce(Offset at, int order, double now) {
    if (_pierce.length < 16) _pierce.add((at, order, now));
  }

  void skull(int bossId, double now) {
    if (_skulls.isEmpty || now - _skulls.last.$2 > 250) _skulls.add((bossId, now));
  }

  void clear() {
    _saws.clear();
    _sweeps.clear();
    _binds.clear();
    _pierce.clear();
    _skulls.clear();
  }

  void paint(Canvas c, double now, List<EnemyPose> poses, int poseCount) {
    _sweeps.removeWhere((s) => now - s.$5 > _sweepMs);
    for (final (ship, target, half, reach, at) in _sweeps) {
      final t = (now - at) / _sweepMs;
      final dir = math.atan2(target.dy - ship.dy, target.dx - ship.dx);
      final sweepA = dir - half + 2 * half * math.min<double>(1, t * 2);
      _path
        ..reset()
        ..moveTo(ship.dx, ship.dy)
        ..arcTo(Rect.fromCircle(center: ship, radius: reach), dir - half, sweepA - (dir - half), false)
        ..close();
      _fill.color = Color.fromRGBO(220, 245, 255, 0.35 * (1 - t));
      c.drawPath(_path, _fill);
      _line
        ..strokeWidth = 3 * (1 - t) + 1
        ..color = Color.fromRGBO(255, 255, 255, 1 - t);
      c.drawArc(Rect.fromCircle(center: ship, radius: reach), dir - half, sweepA - (dir - half), false, _line);
    }
    _saws.removeWhere((s) => now - s.$3 > _sawMs);
    for (final (hit, ship, at) in _saws) {
      final t = (now - at) / _sawMs;
      final p = Offset.lerp(hit, ship, t * t)!;
      final rot = now / 30;
      _fill.color = const Color(0xFFD8DEE8);
      c.drawCircle(p, 4, _fill);
      _fill.color = const Color(0xFF1B1726);
      c.drawCircle(p, 1.5, _fill);
      _line
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFFFFF);
      for (var k = 0; k < 6; k++) {
        final a = rot + k * math.pi / 3;
        c.drawLine(
          p + Offset(math.cos(a), math.sin(a)) * 3.5,
          p + Offset(math.cos(a + 0.5), math.sin(a + 0.5)) * 6,
          _line,
        );
      }
      _line
        ..strokeWidth = 2
        ..color = Color.fromRGBO(220, 230, 255, 0.4 * (1 - t));
      c.drawLine(Offset.lerp(hit, ship, math.max(0, t * t - 0.2))!, p, _line);
    }
    _binds.removeWhere((_, v) => now > v.$2);
    // 엔진 속박 값(EnemyView.rooted)이 기준, 이벤트로 추정한 bind는 그 사이 틱을 메운다.
    for (var k = 0; k < poseCount; k++) {
      final e = poses[k];
      if (!e.rooted && !_binds.containsKey(e.id)) continue;
      final at = Offset(e.drawX, e.drawY + 4);
      final pulse = 0.5 + 0.5 * math.sin(now / 120);
      _line
        ..strokeWidth = 1.5
        ..color = Color.fromRGBO(120, 220, 255, 0.6 + 0.3 * pulse);
      c.drawOval(Rect.fromCenter(center: at, width: 18 + 2 * pulse, height: 8), _line);
      // 이빨 자국: 위아래 작은 삼각 두 줄
      _fill.color = const Color(0xFFF6F1E6);
      for (var i = -1; i <= 1; i++) {
        for (final s in const [-1.0, 1.0]) {
          final x = at.dx + i * 4.0;
          final y = at.dy - 8 + s * 3;
          _path
            ..reset()
            ..moveTo(x - 1.5, y - s * 1.5)
            ..lineTo(x + 1.5, y - s * 1.5)
            ..lineTo(x, y + s * 1.5)
            ..close();
          c.drawPath(_path, _fill);
        }
      }
    }
    _pierce.removeWhere((p) => now - p.$3 > _pierceMs);
    for (final (at, order, ms) in _pierce) {
      final t = (now - ms - order * 30) / _pierceMs;
      if (t < 0 || t >= 1) continue;
      final r = (5 + order * 3.0) * (0.6 + 0.6 * t);
      final glow = math.min<double>(1, 0.5 + order * 0.15);
      _fill.color = Color.fromRGBO(255, 240, 180, glow * (1 - t));
      c.drawCircle(at, r * 0.6, _fill);
      _line
        ..strokeWidth = 1.5 + order * 0.4
        ..color = Color.fromRGBO(255, 210, 90, 1 - t);
      c.drawCircle(at, r, _line);
    }
    _skulls.removeWhere((s) => now - s.$2 > _skullMs);
    for (final (id, at) in _skulls) {
      EnemyPose? boss;
      for (var k = 0; k < poseCount; k++) {
        if (poses[k].id == id) boss = poses[k];
      }
      if (boss == null) continue;
      final t = (now - at) / _skullMs;
      final s = 2.0 * (t < 0.15 ? 1.6 - t / 0.15 * 0.6 : 1.0);
      final fade = t > 0.7 ? (1 - t) / 0.3 : 1.0;
      final ox = boss.drawX - 3 * s;
      final oy = boss.drawY - 34 - 6 * t;
      for (var y = 0; y < _skull.length; y++) {
        for (var x = 0; x < _skull[y].length; x++) {
          final ch = _skull[y][x];
          if (ch == '.') continue;
          _fill.color = (ch == 'y' ? const Color(0xFFFFD24A) : const Color(0xFF1B1726)).withValues(alpha: fade);
          c.drawRect(Rect.fromLTWH(ox + x * s, oy + y * s, s, s), _fill);
        }
      }
    }
  }
}
