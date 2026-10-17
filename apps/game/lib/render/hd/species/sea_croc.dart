import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';

/// 바다 악어(대보스 td_boss:sea_croc) — HD v2 시안: 물에서 상체를 내민 초록 악어. 비늘 무늬·이중 광택·림 라이트(하늘빛 역광)·
/// 그림자 2단, 꼬리·눈썹·콧김까지 움직인다. 표정 3종(k.mood): 평소(턱 딱딱) · 공격 예고(턱 활짝·붉은 눈·팔 번쩍·콧김) ·
/// 쓰러짐(소용돌이 눈·혀·기우뚱·머리 위 별).
const seaCroc = HdSpecies(_seaCroc, extent: 1.5, ground: 0.95);

const _green = Color(0xFF6CD24A);
const _greenD = Color(0xFF256A2A);
const _rimC = Color(0x88D8FFF8);

void _seaCroc(HdKit k, Canvas c, double r, double t) {
  final mood = k.mood;
  final wind = mood == HdMood.windup;
  final down = mood == HdMood.down;
  final bob = k.wave(t, 2) * r * (wind ? 0.05 : 0.03);
  final jaw = down ? 0.55 : (wind ? 0.85 + 0.15 * (k.wave(t, 4) + 1) / 2 : (k.wave(t, 1) + 1) / 2);
  // 짙은 안쪽 그림자(바깥 옅은 그림자는 굽기가 깐다)
  k.fill.color = const Color(0x40061A30);
  c
    ..drawOval(Rect.fromCenter(center: Offset(0, r * 0.95), width: r * 1.3, height: r * 0.34), k.fill)
    ..save();
  if (down) {
    c
      ..translate(0, r * 0.9)
      ..rotate(0.22 + k.wave(t, 1) * 0.03)
      ..translate(0, -r * 0.9);
  }
  _tail(k, c, r, t, wind: wind);
  _arms(k, c, r, t, bob, wind: wind, down: down);
  c
    ..save()
    ..translate(0, bob);
  _body(k, c, r);
  _jaw(k, c, r, jaw);
  _head(k, c, r, t, jaw, wind: wind, down: down);
  c.restore();
  if (down) _stars(k, c, r, t);
  c.restore();
}

void _tail(HdKit k, Canvas c, double r, double t, {required bool wind}) {
  final wag = k.wave(t, wind ? 2 : 1, 1) * r * 0.14;
  final tail = Path()
    ..moveTo(r * 0.35, r * 0.72)
    ..quadraticBezierTo(r * 1.15, r * 0.8 + wag, r * 1.32, r * 0.18 + wag)
    ..quadraticBezierTo(r * 1.05, r * 0.52 + wag * 0.5, r * 0.4, r * 0.45)
    ..close();
  k.blob(c, tail, _green, _greenD, gloss: false);
  // 꼬리 돌기
  for (var i = 0; i < 3; i++) {
    final x = r * (0.75 + i * 0.18);
    final y = r * (0.62 - i * 0.12) + wag * (0.4 + i * 0.2);
    k.blob(
      c,
      Path()
        ..moveTo(x - r * 0.06, y)
        ..lineTo(x, y - r * 0.12)
        ..lineTo(x + r * 0.06, y)
        ..close(),
      _green,
      _greenD,
      gloss: false,
      line: 0.55,
    );
  }
}

void _arms(HdKit k, Canvas c, double r, double t, double bob, {required bool wind, required bool down}) {
  for (final s in const [-1.0, 1.0]) {
    final sw = k.wave(t, 2, s) * r * 0.08;
    // 예고: 팔을 번쩍 들고, 쓰러짐: 축 늘어짐
    final hand = down
        ? Offset(s * r * 0.95, r * 0.75)
        : (wind ? Offset(s * r * 1.08, -r * 0.2 + sw) : Offset(s * r * 1.0, r * 0.45 + sw));
    final arm = Path()
      ..moveTo(s * r * 0.5, r * 0.2 + bob)
      ..quadraticBezierTo(s * r * 0.95, r * 0.12 + sw, hand.dx, hand.dy);
    k.limb(c, arm, _greenD, r * 0.2);
    // 손톱 셋
    final nail = Offset(0, wind ? -r * 0.06 : r * 0.06);
    for (var f = -1; f <= 1; f++) {
      k.blob(
        c,
        Path()..addOval(Rect.fromCircle(center: hand + nail + Offset(f * r * 0.07, 0), radius: r * 0.05)),
        const Color(0xFFFFF4DC),
        const Color(0xFFD8C8A0),
        gloss: false,
        line: 0.35,
      );
    }
  }
}

void _body(HdKit k, Canvas c, double r) {
  final body = Path()
    ..moveTo(-r * 0.6, r * 0.88)
    ..cubicTo(-r * 0.78, r * 0.1, -r * 0.55, -r * 0.35, 0, -r * 0.35)
    ..cubicTo(r * 0.55, -r * 0.35, r * 0.78, r * 0.1, r * 0.6, r * 0.88)
    ..close();
  k.blob(c, body, _green, _greenD);
  // 등 비늘(몸 양옆) — 몸 안으로 잘라 그린다
  c
    ..save()
    ..clipPath(body);
  k.scales(c, Rect.fromLTRB(-r * 0.7, -r * 0.2, r * 0.7, r * 0.9), r * 0.16, const Color(0x55194A1E));
  c.restore();
  final belly = Path()
    ..moveTo(-r * 0.33, r * 0.88)
    ..quadraticBezierTo(-r * 0.42, r * 0.05, 0, 0)
    ..quadraticBezierTo(r * 0.42, r * 0.05, r * 0.33, r * 0.88)
    ..close();
  k.blob(c, belly, const Color(0xFFFFF4B8), const Color(0xFFE0B860), gloss: false, line: 0.6);
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 0.45;
  for (var i = 1; i <= 4; i++) {
    final y = r * (0.08 + i * 0.16);
    c.drawLine(Offset(-r * 0.3, y), Offset(r * 0.3, y), k.ink);
  }
  k.ink.strokeWidth = w;
  k
    ..rim(c, body, _rimC)
    ..shine2(c, body.getBounds());
}

void _jaw(HdKit k, Canvas c, double r, double jaw) {
  final drop = r * 0.26 * jaw;
  final lower = Path()
    ..moveTo(-r * 0.56, -r * 0.45)
    ..quadraticBezierTo(-r * 0.62, -r * 0.05 + drop, 0, drop)
    ..quadraticBezierTo(r * 0.62, -r * 0.05 + drop, r * 0.56, -r * 0.45)
    ..close();
  k.mouth(c, lower);
  // 혀(입 안 분홍)
  k.fill.color = const Color(0xFFFF6A8A);
  c.drawOval(
    Rect.fromCenter(center: Offset(0, -r * 0.12 + drop * 0.7), width: r * 0.42, height: r * 0.16 + drop * 0.3),
    k.fill,
  );
  for (var i = 0; i < 4; i++) {
    k.tooth(c, Offset(-r * 0.4 + i * r * 0.2, -r * 0.08 + drop * 0.9), r * 0.14, -r * 0.15);
  }
}

void _head(HdKit k, Canvas c, double r, double t, double jaw, {required bool wind, required bool down}) {
  for (var i = 0; i < 5; i++) {
    k.tooth(c, Offset(-r * 0.5 + i * r * 0.2, -r * 0.41), r * 0.14, r * 0.16);
  }
  final head = Path()
    ..moveTo(-r * 0.62, -r * 0.42)
    ..cubicTo(-r * 0.72, -r * 1.28, r * 0.72, -r * 1.28, r * 0.62, -r * 0.42)
    ..quadraticBezierTo(0, -r * 0.3, -r * 0.62, -r * 0.42)
    ..close();
  k.blob(c, head, const Color(0xFF8CE86A), _greenD);
  c
    ..save()
    ..clipPath(head);
  k.scales(c, Rect.fromLTRB(-r * 0.6, -r * 1.2, r * 0.6, -r * 0.6), r * 0.14, const Color(0x44194A1E));
  c.restore();
  k
    ..rim(c, head, _rimC)
    ..shine2(c, head.getBounds())
    ..spots(c, r, const [(-0.12, -0.56, 0.045), (0.12, -0.56, 0.045)], HdKit.inkColor);
  // 콧김(평소엔 가끔, 예고 땐 붉은 김이 계속)
  final puff = wind ? 1.0 : (k.wave(t, 1, -1.5) + 1) / 2;
  if (puff > 0.55 && !down) {
    final u = wind ? (t / HdKit.loopMs * 2) % 1 : (puff - 0.55) / 0.45;
    k.fill.color = wind ? Color.fromRGBO(255, 90, 70, 0.75 * (1 - u)) : Color.fromRGBO(255, 255, 255, 0.7 * (1 - u));
    for (final s in const [-1.0, 1.0]) {
      c.drawCircle(Offset(s * r * (0.14 + u * 0.12), -r * (0.62 + u * 0.25)), r * (0.05 + u * 0.06), k.fill);
    }
  }
  // 눈(혹 위) + 눈썹
  final brow = k.wave(t, 2, 0.5) * r * 0.025;
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.33, -r * 1.04);
    final bump = Path()..addOval(Rect.fromCenter(center: at + Offset(0, r * 0.02), width: r * 0.44, height: r * 0.36));
    k
      ..blob(c, bump, _green, _greenD, gloss: false)
      ..rim(c, bump, _rimC, width: 0.6);
    if (down) {
      k.dizzyEye(c, at, r * 0.3, t * s);
    } else {
      k.eye(c, at, r * 0.32, look: -0.3);
      if (wind) {
        // 공격 예고: 붉게 타는 눈동자
        k.fill.color = const Color(0xFFFF3A2A);
        c.drawCircle(at + Offset(-r * 0.015, r * 0.03), r * 0.07, k.fill);
        k.fill.color = const Color(0xFFFFE07A);
        c.drawCircle(at + Offset(-r * 0.015, r * 0.03), r * 0.03, k.fill);
      }
      c.drawLine(
        at + Offset(-s * r * 0.2, -r * (wind ? 0.24 : 0.2) + brow),
        at + Offset(s * r * 0.16, -r * (wind ? 0.12 : 0.15) + brow),
        k.ink,
      );
    }
  }
  if (down) {
    // 혀 쭉
    k.limb(
      c,
      Path()
        ..moveTo(r * 0.1, -r * 0.05)
        ..quadraticBezierTo(r * 0.22, r * 0.12, r * 0.16, r * 0.24),
      const Color(0xFFFF6A8A),
      r * 0.09,
    );
  }
}

/// 쓰러짐: 머리 위를 도는 별 셋.
void _stars(HdKit k, Canvas c, double r, double t) {
  for (var i = 0; i < 3; i++) {
    final a = 2 * math.pi * (t / HdKit.loopMs + i / 3);
    final at = Offset(math.cos(a) * r * 0.5, -r * 1.35 + math.sin(a) * r * 0.12);
    final s = r * 0.14;
    final p = Path();
    for (var j = 0; j < 10; j++) {
      final rr = j.isEven ? s : s * 0.45;
      final b = -math.pi / 2 + j * math.pi / 5;
      final q = at + Offset(math.cos(b) * rr, math.sin(b) * rr);
      j == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    p.close();
    k.blob(c, p, const Color(0xFFFFF4A0), const Color(0xFFFFC23A), gloss: false, line: 0.35);
  }
}
