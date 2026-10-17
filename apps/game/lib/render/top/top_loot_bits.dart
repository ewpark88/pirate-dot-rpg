import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/sprite_draw.dart';

/// 보상 터짐(TopBossLoot)의 그림 조각: 금빛 기둥·별가루·젬·카드. 전장 좌표.
class LootBits {
  final _paint = Paint()..isAntiAlias = false;
  final _path = Path();

  /// 하늘로 솟는 금빛 기둥(0~900ms): 넓은 옅은 띠 + 가운데 밝은 줄, 위로 갈수록 옅게.
  void pillar(Canvas c, Offset at, double age, {required bool wide}) {
    const ms = 900.0;
    if (age >= ms) return;
    final t = age / ms;
    final rise = math.min<double>(1, t * 4);
    final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    final h = 150 * rise;
    final w = (wide ? 22 : 16) * (1 - t * 0.5);
    for (var k = 0; k < 4; k++) {
      final y0 = at.dy - h * k / 4;
      final y1 = at.dy - h * (k + 1) / 4;
      _paint.color = Color.fromRGBO(255, 214, 90, 0.4 * fade * (1 - k / 4));
      c.drawRect(Rect.fromLTRB(at.dx - w / 2, y1, at.dx + w / 2, y0), _paint);
      _paint.color = Color.fromRGBO(255, 250, 220, 0.85 * fade * (1 - k / 4));
      c.drawRect(Rect.fromLTRB(at.dx - w / 6, y1, at.dx + w / 6, y0), _paint);
    }
  }

  /// 별가루(광고 보상): 배 둘레에서 빙글 돌며 솟아오르는 반짝 12개.
  void stars(Canvas c, Offset at, double age) {
    const ms = 1200.0;
    if (age >= ms) return;
    final t = age / ms;
    for (var k = 0; k < 12; k++) {
      final a = k * math.pi / 6 + t * 3;
      final r = 14 + 10 * math.sin(k * 1.3) + 8 * t;
      final p = at + Offset(math.cos(a) * r, math.sin(a) * r * 0.6 - 50 * t);
      _paint.color = Color.fromRGBO(255, 236, 140, 1 - t);
      final s = (k.isEven ? 2.0 : 1.0) + ((age / 100 + k).floor().isEven ? 1 : 0);
      c
        ..drawRect(Rect.fromCenter(center: p, width: s * 3, height: s), _paint)
        ..drawRect(Rect.fromCenter(center: p, width: s, height: s * 3), _paint);
    }
  }

  /// 젬: 분홍·하늘 마름모(테두리·하이라이트) + 반짝.
  void gem(Canvas c, Offset p, double age) {
    final x = p.dx.roundToDouble();
    final y = p.dy.roundToDouble();
    _path
      ..reset()
      ..moveTo(x, y - 7)
      ..lineTo(x + 5, y - 1)
      ..lineTo(x, y + 6)
      ..lineTo(x - 5, y - 1)
      ..close();
    _paint.color = const Color(0xFF1B1726);
    c.drawPath(_path.shift(const Offset(0, 1)), _paint);
    _paint.color = const Color(0xFFE0479E);
    c.drawPath(_path, _paint);
    _paint.color = const Color(0xFFFF9AD5);
    c.drawRect(Rect.fromLTWH(x - 3, y - 2, 3, 2), _paint);
    _paint.color = const Color(0xFFFFFFFF);
    c.drawRect(Rect.fromLTWH(x - 2, y - 4, 1, 2), _paint);
    if ((age / 120).floor().isEven) c.drawRect(Rect.fromLTWH(x + 3, y - 7, 1, 1), _paint);
  }

  /// 카드: 등급 색 테두리 + 선원 초상, 가로로 뒤집히며 돈다.
  void card(Canvas c, Offset p, (String, int) card, double age, SpriteDraw? sprites) {
    final flip = math.cos(age / 140).abs().clamp(0.25, 1.0);
    final w = 12 * flip;
    const h = 16.0;
    final r = Rect.fromCenter(center: p, width: w + 2, height: h + 2);
    _paint.color = const Color(0xFF1B1726);
    c.drawRect(r, _paint);
    _paint.color = Color(card.$2);
    c.drawRect(r.deflate(1), _paint);
    _paint.color = const Color(0xFFF6EBD0);
    c.drawRect(r.deflate(2.5), _paint);
    sprites?.drawSmooth(c, 'crew:${card.$1}', p.dx, p.dy, w - 3, w - 3);
  }
}
