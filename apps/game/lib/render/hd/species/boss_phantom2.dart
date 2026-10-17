import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 밴시 여왕(td_boss:banshee_queen, 유령 순환 v2): 머리칼이 물결처럼 흩날리는 창백한 유령 여왕 — 왕관·벌린 입.
const bansheeQueen = HdSpecies(_bansheeQueen, extent: 1.5, ground: 1.2);

/// 저주받은 종(td_boss:cursed_bell): 쇠사슬 감긴 녹슨 종, 안에서 초록 눈이 번뜩이며 흔들린다.
const cursedBell = HdSpecies(_cursedBell, extent: 1.5, ground: 1.05);

/// 유령 크라켄(td_boss:ghost_kraken): 반투명 초록 크라켄, 촉수에 사슬이 감겼다.
const ghostKraken = HdSpecies(_ghostKraken, extent: 1.55, ground: 1.1);

final _line = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

/// 사슬 고리 [n]개를 [a]→[b] 위에 그린다.
void _chain(Canvas c, Offset a, Offset b, double r, int n) {
  _line
    ..strokeWidth = r * 0.035
    ..color = const Color(0xFF8A8A9A);
  for (var i = 0; i < n; i++) {
    final p = Offset.lerp(a, b, (i + 0.5) / n)!;
    c.drawOval(
      Rect.fromCenter(center: p, width: r * (i.isEven ? 0.16 : 0.08), height: r * (i.isEven ? 0.09 : 0.14)),
      _line,
    );
  }
}

void _bansheeQueen(HdKit k, Canvas c, double r, double t) {
  final f = k.wave(t, 1) * r * 0.07;
  // 흩날리는 머리칼(뒤, 물결 띠 5)
  for (var i = 0; i < 5; i++) {
    final x = (i - 2) * r * 0.25;
    final hair = Path()
      ..moveTo(x, -r * 0.6 + f)
      ..cubicTo(
        x + r * 0.3 * math.sin(t / 150 + i),
        -r * 0.1,
        x - r * 0.3 * math.sin(t / 130 + i),
        r * 0.4,
        x + r * 0.15 * math.sin(t / 110 + i),
        r * 0.95,
      );
    k.limb(c, hair, const Color(0xFFDCE6FF), r * 0.1);
  }
  // 드레스 몸(아래 물결)
  final body = Path()
    ..moveTo(-r * 0.45, -r * 0.2 + f)
    ..lineTo(r * 0.45, -r * 0.2 + f);
  for (var i = 0; i < 4; i++) {
    final x = r * (0.45 - (i + 1) * 0.225);
    body.quadraticBezierTo(x + r * 0.11, r * (0.95 + (i.isEven ? 0.1 : 0)) + f, x, r * 0.75 + f);
  }
  body.close();
  k.fill
    ..color =
        const Color(0xFFFFFFFF) // 앞 반투명 색 알파가 그라데이션에 곱해지지 않게
    ..shader = Gradient.linear(Offset(0, -r * 0.2), Offset(0, r), const [Color(0xF0E8ECFF), Color(0x8090A0D8)]);
  c.drawPath(body, k.fill);
  k.fill.shader = null;
  c.drawPath(body, k.ink);
  // 얼굴
  final face = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.45 + f), width: r * 0.78, height: r * 0.84));
  k
    ..blob(c, face, const Color(0xFFF4F6FF), const Color(0xFF8A94C0))
    ..eye(c, Offset(-r * 0.15, -r * 0.52 + f), r * 0.25, angry: true)
    ..eye(c, Offset(r * 0.15, -r * 0.52 + f), r * 0.25, angry: true)
    ..mouth(
      c,
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(0, -r * 0.25 + f),
          width: r * 0.16,
          height: r * (0.14 + 0.06 * (k.wave(t, 2) + 1) / 2),
        ),
      ),
    )
    ..crown(c, Offset(0, -r * 0.85 + f), r * 0.45);
  // 비명 파동
  final u = (t / HdKit.loopMs) % 1;
  _line
    ..strokeWidth = r * 0.03
    ..color = Color.fromRGBO(200, 220, 255, 0.6 * (1 - u));
  c.drawArc(Rect.fromCircle(center: Offset(0, -r * 0.25 + f), radius: r * (0.25 + 0.5 * u)), 0.6, 1.9, false, _line);
}

void _cursedBell(HdKit k, Canvas c, double r, double t) {
  const rust = Color(0xFF8A6A3A);
  const rustD = Color(0xFF3A2A14);
  final swing = k.wave(t, 1) * 0.18;
  c
    ..save()
    ..translate(0, -r * 0.9)
    ..rotate(swing)
    ..translate(0, r * 0.9);
  // 종 몸
  final bell = Path()
    ..moveTo(-r * 0.25, -r * 0.75)
    ..quadraticBezierTo(-r * 0.6, -r * 0.6, -r * 0.65, r * 0.3)
    ..quadraticBezierTo(-r * 0.9, r * 0.5, -r * 0.85, r * 0.6)
    ..lineTo(r * 0.85, r * 0.6)
    ..quadraticBezierTo(r * 0.9, r * 0.5, r * 0.65, r * 0.3)
    ..quadraticBezierTo(r * 0.6, -r * 0.6, r * 0.25, -r * 0.75)
    ..close();
  k
    ..blob(c, bell, const Color(0xFFB08A50), rustD)
    ..spots(c, r, const [(-0.3, -0.1, 0.08), (0.35, 0.1, 0.06), (0.1, -0.4, 0.05)], const Color(0xAA4A7A5A));
  // 종 입구 안 어둠 + 초록 눈
  k.fill.color = const Color(0xFF14101C);
  c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.6), width: r * 1.5, height: r * 0.35), k.fill);
  k
    ..eye(c, Offset(-r * 0.2, r * 0.05), r * 0.24, angry: true)
    ..eye(c, Offset(r * 0.2, r * 0.05), r * 0.24, angry: true);
  // 꼭대기 고리
  _line
    ..strokeWidth = r * 0.07
    ..color = rust;
  c
    ..drawCircle(Offset(0, -r * 0.85), r * 0.12, _line)
    ..restore();
  // 감긴 쇠사슬(대각선 둘)
  _chain(c, Offset(-r * 0.75, r * 0.25), Offset(r * 0.75, r * 0.4), r, 9); // 눈 아래로 감긴 사슬
}

void _ghostKraken(HdKit k, Canvas c, double r, double t) {
  const green = Color(0xEE8AF0C0);
  final bob = k.wave(t, 1) * r * 0.05;
  for (var i = 0; i < 6; i++) {
    final a = math.pi * (0.15 + i * 0.14);
    final base = Offset(math.cos(a) * r * 0.45, r * 0.25 + bob);
    k.tentacle(c, base, a, r * 0.75, k.wave(t, 1, i * 0.9) * 0.6, green, r * 0.17);
    if (i == 1 || i == 4) {
      final tip = base + Offset(math.cos(a), math.sin(a)) * r * 0.55;
      _chain(c, base, tip, r, 5);
    }
  }
  final head = Path()
    ..moveTo(-r * 0.6, r * 0.3 + bob)
    ..cubicTo(-r * 0.75, -r * 1.05 + bob, r * 0.75, -r * 1.05 + bob, r * 0.6, r * 0.3 + bob)
    ..close();
  k.fill
    ..color =
        const Color(0xFFFFFFFF) // 앞 반투명 색 알파가 그라데이션에 곱해지지 않게
    ..shader = Gradient.linear(Offset(0, -r), Offset(0, r * 0.3), const [Color(0xF4D8FFEE), Color(0xE070D8B0)]);
  c.drawPath(head, k.fill);
  k.fill.shader = null;
  c.drawPath(head, k.ink);
  k
    ..shine(c, head.getBounds())
    ..eye(c, Offset(-r * 0.22, -r * 0.2 + bob), r * 0.28, angry: true)
    ..eye(c, Offset(r * 0.22, -r * 0.2 + bob), r * 0.28, angry: true);
}
