import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/fx/transients.dart';

/// 탑다운 해일 (S1 '해일 쐐기가 네모로 잘려 보인다'): 옆모습 그림 tidal_wave(물마루가 바닥 선에서 솟는 옆 그림)는 위에서 보면
/// 납작한 바닥·잘린 옆면이 보인다. 탑다운은 코드로 그린다 — 제자리 스킬은 퍼지는 물 고리(파란 띠 + 흰 물마루 + 거품),
/// 움직이는 궁극기(vx ≠ 0)는 진행 방향으로 볼록한 물 벽(띠·물마루) + 뒤에 거품 자국.
class TopWaveFx {
  final _band = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _dot = Paint()..isAntiAlias = false;
  static const _blue = Color(0xFF3FA7E0);
  static const _deep = Color(0xFF1F6FB8);
  static const _foam = Color(0xFFF2FBFF);

  void paint(Canvas c, Effect e) {
    final life = math.max(1, e.frames * e.frameMs);
    final t = ((e.ageMs - e.delayMs) / life).clamp(0.0, 1.0);
    final fade = 1 - t;
    if (e.vx != 0) {
      _front(c, e, t, fade);
      return;
    }
    final at = Offset(e.x, e.y);
    final r = 5 + 22 * t;
    _band
      ..strokeWidth = 2 + 5 * fade
      ..color = _deep.withValues(alpha: 0.55 * fade);
    c.drawCircle(at, r - 1.5, _band);
    _band
      ..strokeWidth = 1.5 + 3 * fade
      ..color = _blue.withValues(alpha: 0.85 * fade);
    c.drawCircle(at, r, _band);
    _band
      ..strokeWidth = 1.2
      ..color = _foam.withValues(alpha: fade);
    c.drawCircle(at, r + 2, _band);
    for (var k = 0; k < 10; k++) {
      final a = k * math.pi / 5 + t * 1.5;
      final d = r + 3 + (k % 3);
      _dot.color = _foam.withValues(alpha: 0.9 * fade);
      c.drawRect(Rect.fromLTWH(at.dx + math.cos(a) * d, at.dy + math.sin(a) * d, 1.5, 1.5), _dot);
    }
  }

  /// 움직이는 물 벽: 높이 90단위, 진행 쪽으로 볼록, 뒤로 거품 줄.
  void _front(Canvas c, Effect e, double t, double fade) {
    final dir = e.vx.sign;
    final a = 0.4 + 0.6 * math.min(1, t * 6) * math.min(1, fade * 4);
    final path = Path()
      ..moveTo(e.x - dir * 6, e.y - 45)
      ..quadraticBezierTo(e.x + dir * 10, e.y, e.x - dir * 6, e.y + 45);
    _band
      ..strokeWidth = 12
      ..color = _deep.withValues(alpha: 0.5 * a);
    c.drawPath(path.shift(Offset(-dir * 5, 0)), _band);
    _band
      ..strokeWidth = 7
      ..color = _blue.withValues(alpha: 0.9 * a);
    c.drawPath(path, _band);
    _band
      ..strokeWidth = 2
      ..color = _foam.withValues(alpha: a);
    c.drawPath(path.shift(Offset(dir * 4, 0)), _band);
    for (var k = 0; k < 14; k++) {
      final y = e.y - 42 + k * 6.5;
      final back = 8 + (k * 7 % 13);
      _dot.color = _foam.withValues(alpha: 0.7 * a);
      c.drawRect(Rect.fromLTWH(e.x - dir * back, y, 2, 1), _dot);
    }
  }
}
