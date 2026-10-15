import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';

/// PB 무기 그림이 없는 선원(강습 5명)의 발사체: 코드로 그린 갈고리 + 배에서 이어진 밧줄 + 선원 얼굴 배지(portrait).
/// S1: '선원을 바꾸면 폭탄 그림도 바뀌어 보여야' — 40명 모두 서로 다른 그림이 되게.
class HookPainter {
  HookPainter(this.sprites);

  final SpriteDraw sprites;
  final _paint = Paint()..isAntiAlias = true;
  final _rope = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const _metal = Color(0xFFC9D2E3);
  static const _metalEdge = Color(0xFF353B4C);
  static const _ropeColor = Color(0xFFB8864B);
  static const _badgeRing = Color(0xFFFFFFFF);

  /// 얼굴 그림이 없으면 false (도트 발사체로).
  bool paint(Canvas c, Projectile p, double size) {
    final face = 'portrait:${p.crewId}';
    if (sprites.sheet(face) == null) return false;
    // 밧줄: 뱃머리에서 갈고리까지 살짝 처진 줄.
    _rope
      ..strokeWidth = size * 0.07
      ..color = _ropeColor;
    final mid = Offset((kShipNoseX + p.x) / 2, (kShipNoseY + p.y) / 2 + size * 0.4);
    c.drawPath(
      Path()
        ..moveTo(kShipNoseX, kShipNoseY)
        ..quadraticBezierTo(mid.dx, mid.dy, p.x, p.y),
      _rope,
    );
    // 갈고리: 앞을 향한 세 갈래 (진행 방향으로 돌림).
    final a = math.atan2(p.toY - p.fromY, p.toX - p.fromX);
    c
      ..save()
      ..translate(p.x, p.y)
      ..rotate(a);
    final u = size / 10;
    _rope
      ..strokeWidth = u * 1.6
      ..color = _metalEdge;
    _prongs(c, u);
    _rope
      ..strokeWidth = u * 0.9
      ..color = _metal;
    _prongs(c, u);
    c.restore();
    // 얼굴 배지: 갈고리 뒤 둥근 초상.
    final r = size * 0.36;
    final at = Offset(p.x - math.cos(a) * u * 4, p.y - math.sin(a) * u * 4);
    _paint.color = _badgeRing;
    c
      ..drawCircle(at, r + u * 0.8, _paint)
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: r)));
    sprites.drawSmooth(c, face, at.dx, at.dy + r * 0.15, r * 2.3, r * 2.3);
    c.restore();
    return true;
  }

  void _prongs(Canvas c, double u) {
    c
      ..drawLine(Offset(-u * 3, 0), Offset(u * 3, 0), _rope)
      ..drawPath(
        Path()
          ..moveTo(u * 3, 0)
          ..quadraticBezierTo(u * 4.5, -u * 3.5, u * 1.5, -u * 4)
          ..moveTo(u * 3, 0)
          ..quadraticBezierTo(u * 4.5, u * 3.5, u * 1.5, u * 4),
        _rope,
      );
  }
}
