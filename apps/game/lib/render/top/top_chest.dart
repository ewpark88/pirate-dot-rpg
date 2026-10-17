import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/scene_state.dart';

/// 떠내려온 보물상자를 '누르고 싶게'(피드백 #6): 뒤에서 도는 금빛 빛줄기·물 위 금빛 반사(맥박),
/// 1.8초마다 들썩(좌우로 흔들며 통 튐), 상자 위를 지나가는 반짝 줄, 둘레 별 반짝. 가라앉을수록 옅어진다. 전장 좌표.
class TopChest {
  final _fill = Paint()..isAntiAlias = false;
  final _ray = Path();

  static const _wiggleEveryMs = 1800.0;
  static const _wiggleMs = 360.0;
  static const _sheenEveryMs = 2200.0;
  static const _sheenMs = 420.0;

  void paint(Canvas c, SpriteDraw sprites, ChestPose ch, double now, {required bool lite}) {
    if (!ch.visible) return;
    final alpha = 1 - 0.7 * ch.sink;
    final at = Offset(ch.x.roundToDouble(), ch.y.roundToDouble());
    final pulse = 0.5 + 0.5 * math.sin(now / 260);
    // 물 위 금빛 반사
    _fill.color = Color.fromRGBO(255, 214, 90, (0.22 + 0.18 * pulse) * alpha);
    c.drawOval(Rect.fromCenter(center: at + const Offset(0, 5), width: 30 + 6 * pulse, height: 12 + 2 * pulse), _fill);
    // 뒤에서 도는 빛줄기
    if (!lite) {
      final r = 20 + 3 * pulse;
      _ray.reset();
      for (var k = 0; k < 6; k++) {
        final a = now / 1400 + k * math.pi / 3;
        _ray
          ..moveTo(at.dx, at.dy)
          ..lineTo(at.dx + math.cos(a - 0.16) * r, at.dy + math.sin(a - 0.16) * r)
          ..lineTo(at.dx + math.cos(a + 0.16) * r, at.dy + math.sin(a + 0.16) * r)
          ..close();
      }
      _fill.color = Color.fromRGBO(255, 230, 140, 0.28 * alpha);
      c.drawPath(_ray, _fill);
    }
    // 들썩: 좌우로 흔들며 통 튐
    final w = now % _wiggleEveryMs;
    final wt = w < _wiggleMs ? w / _wiggleMs : 1.0;
    final tilt = wt < 1 ? math.sin(wt * math.pi * 4) * 0.22 * (1 - wt) : 0.0;
    final hop = wt < 1 ? math.sin(wt * math.pi) * 3 : 0.0;
    c
      ..save()
      ..translate(at.dx, at.dy - hop)
      ..rotate(tilt);
    final sheet = sprites.sheet('td_event:chest');
    sprites.draw(c, 'td_event:chest', 0, 0, frame: (now / 450).floor() % 2, alpha: alpha);
    // 반짝 줄: 상자 위를 왼쪽 위 → 오른쪽 아래로 지나감
    final sw = now % _sheenEveryMs;
    if (sheet != null && sw < _sheenMs) {
      final hw = sheet.frameW / 2;
      final hh = sheet.frameH / 2;
      final x = -hw - 6 + (sheet.frameW + 12) * (sw / _sheenMs);
      c
        ..save()
        ..clipRect(Rect.fromLTRB(-hw + 1, -hh + 1, hw - 1, hh - 1));
      _fill.color = Color.fromRGBO(255, 255, 240, 0.7 * alpha);
      c
        ..drawPath(
          Path()
            ..moveTo(x, -hh)
            ..lineTo(x + 3, -hh)
            ..lineTo(x - 3, hh)
            ..lineTo(x - 6, hh)
            ..close(),
          _fill,
        )
        ..restore();
    }
    c.restore();
    // 둘레 별 반짝(번갈아)
    for (var k = 0; k < (lite ? 2 : 4); k++) {
      final tw = math.sin(now / 180 + k * 1.7);
      if (tw < 0.2) continue;
      final a = k * math.pi / 2 + 0.6 + now / 3000;
      final p = at + Offset(math.cos(a) * 14, math.sin(a) * 10 - 2);
      final s = 1 + (tw > 0.75 ? 1.0 : 0.0);
      _fill.color = Color.fromRGBO(255, 248, 200, tw * alpha);
      c
        ..drawRect(Rect.fromCenter(center: p, width: s * 3, height: s), _fill)
        ..drawRect(Rect.fromCenter(center: p, width: s, height: s * 3), _fill);
    }
  }
}
