import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/sprite_draw.dart';

/// 보상 터짐(TopBossLoot)의 그림 조각: 금빛 기둥·별가루·젬·카드. 전장 좌표.
class LootBits {
  final _paint = Paint()..isAntiAlias = false;
  final _path = Path();
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

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

  /// 보물상자 V자 빛줄기(디자인 개편 — 쿵푸할매 상자 연출): 상자에서 위로 벌어지는 보라 빛줄기 두 개, 그 안을 금화·젬이 줄지어 솟는다(1.2초).
  void vBeams(Canvas c, Offset at, double age, SpriteDraw? sprites) {
    const ms = 1200.0;
    if (age >= ms) return;
    final t = age / ms;
    final rise = math.min<double>(1, t * 3);
    final fade = t < 0.65 ? 1.0 : 1 - (t - 0.65) / 0.35;
    const len = 170.0;
    for (final side in const [-1.0, 1.0]) {
      final dir = Offset(math.sin(side * 0.36), -math.cos(0.36));
      final tip = at + dir * len * rise;
      final n = Offset(-dir.dy, dir.dx);
      for (final (w, a) in const [(14.0, 0.28), (7.0, 0.5), (2.5, 0.9)]) {
        _path
          ..reset()
          ..moveTo(at.dx + n.dx * w * 0.4, at.dy + n.dy * w * 0.4)
          ..lineTo(tip.dx + n.dx * w, tip.dy + n.dy * w)
          ..lineTo(tip.dx - n.dx * w, tip.dy - n.dy * w)
          ..lineTo(at.dx - n.dx * w * 0.4, at.dy - n.dy * w * 0.4)
          ..close();
        _paint.color = (w < 3 ? const Color(0xFFF4E6FF) : const Color(0xFFB45AFF)).withValues(alpha: a * fade);
        c.drawPath(_path, _paint);
      }
      // 빛줄기 안을 솟는 보상: 금화·젬 번갈아 6개
      for (var k = 0; k < 6; k++) {
        final u = ((t * 1.6) + k / 6) % 1;
        if (u > rise) continue;
        final p = at + dir * len * u;
        final s = 9 * (0.7 + 0.3 * u);
        if (k.isEven &&
            sprites != null &&
            sprites.drawSmoothFrame(c, 'coin_hd', (k + (age ~/ 70)) % 4, p.dx, p.dy, s, s)) {
          continue;
        }
        c
          ..save()
          ..translate(p.dx, p.dy)
          ..scale(1.2);
        gem(c, Offset.zero, age + k * 40);
        c.restore();
      }
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

  /// 카드: 등급 색 테두리 + 선원 초상 + 아래 등급 별([stars]개). [spin]이면 가로로 천천히 뒤집히며 돈다(폭 60% 아래로는 안 줄어듦).
  /// [back]이면 뒷면(남색 바탕·금 테·닻), [scaleX]는 뒤집기 폭(0~1).
  void card(
    Canvas c,
    Offset p,
    (String, int) card,
    double age,
    SpriteDraw? sprites, {
    bool spin = true,
    bool back = false,
    double scaleX = 1,
    int stars = 0,
  }) {
    final flip = spin ? math.cos(age / 260).abs().clamp(0.6, 1.0) : scaleX.clamp(0.08, 1.0);
    final w = 14 * flip;
    const h = 19.0;
    final r = Rect.fromCenter(center: p, width: w + 2, height: h + 2);
    _paint.color = const Color(0xFF1B1726);
    c.drawRect(r, _paint);
    if (back) {
      _paint.color = const Color(0xFFE0A93A);
      c.drawRect(r.deflate(1), _paint);
      _paint.color = const Color(0xFF223A6A);
      c.drawRect(r.deflate(2.5), _paint);
      _paint.color = const Color(0xFFE0A93A);
      c
        ..drawRect(Rect.fromCenter(center: p, width: math.max(1, w * 0.12), height: 9), _paint)
        ..drawRect(Rect.fromCenter(center: p + const Offset(0, -3), width: w * 0.45, height: 1.2), _paint)
        ..drawRect(Rect.fromCenter(center: p + const Offset(0, 4), width: w * 0.55, height: 1.2), _paint);
      return;
    }
    _paint.color = Color(card.$2);
    c.drawRect(r.deflate(1), _paint);
    _paint.color = const Color(0xFFF6EBD0);
    c.drawRect(r.deflate(2.5), _paint);
    sprites?.drawSmooth(c, 'crew:${card.$1}', p.dx, p.dy - 1, w - 3, w - 3);
    if (stars > 0 && flip > 0.5) {
      // 등급 띠: 아래쪽 등급 색 띠 위에 노란 별
      _paint.color = Color(card.$2);
      c.drawRect(Rect.fromLTWH(r.left + 1, r.bottom - 5, r.width - 2, 4), _paint);
      _paint.color = const Color(0xFFFFE24A);
      final n = math.min(5, stars);
      final x0 = p.dx - (n * 2.4) / 2 + 0.6;
      for (var k = 0; k < n; k++) {
        c.drawRect(Rect.fromLTWH(x0 + k * 2.4, r.bottom - 4, 1.4, 1.4), _paint);
      }
    }
  }

  /// 새 동료 카드 뒤 후광: 등급 색 빛줄기가 돌고 고리가 맥박친다.
  void halo(Canvas c, Offset p, double age, int big, int color) {
    final r = 14 * (1 + 0.8 * big) + 14;
    // 환영(2)은 금빛, 새 동료(1)는 등급 색 — 파란 바다에서도 보이게 알파를 넉넉히.
    _paint.color = big >= 2 ? const Color(0x88FFD84A) : Color(color).withValues(alpha: 0.5);
    _path.reset();
    for (var k = 0; k < 8; k++) {
      final a = age / 600 + k * math.pi / 4;
      _path
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx + math.cos(a - 0.14) * r, p.dy + math.sin(a - 0.14) * r)
        ..lineTo(p.dx + math.cos(a + 0.14) * r, p.dy + math.sin(a + 0.14) * r)
        ..close();
    }
    c.drawPath(_path, _paint);
    _ring
      ..strokeWidth = 1.5
      ..color = const Color(0xCCFFE27A);
    c.drawCircle(p, r * (0.55 + 0.08 * math.sin(age / 90)), _ring);
  }

  /// 배 둘레 흡수 반짝(이번 프레임 도착 수만큼 굵게).
  void absorb(Canvas c, Offset ship, int n) {
    _ring
      ..strokeWidth = math.min(4, 1 + n * 0.5)
      ..color = const Color(0xCCFFE27A);
    c.drawCircle(ship, 14 + math.min(8, n * 1.0), _ring);
  }
}
