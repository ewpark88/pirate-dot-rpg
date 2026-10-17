import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 저주 갈매기 대장(td_boss:cursegull_leader): 금관 쓴 보라 갈매기 — 찢긴 날개를 크게 퍼덕이며 붉은 눈으로 노려본다.
const cursegullLeader = HdSpecies(_cursegullLeader, extent: 1.55, ground: 1.3);

/// 용암 거북(td_boss:lava_tortoise): 금 간 등껍질 틈으로 용암이 빛나는 거북 — 고개를 까딱, 등에서 김이 오른다.
const lavaTortoise = HdSpecies(_lavaTortoise, extent: 1.5, ground: 0.85);

/// 물범 대장(td_boss:seal_chief): 투구 쓴 회색 물범 — 지느러미로 배를 두드리고 수염을 씰룩.
const sealChief = HdSpecies(_sealChief, extent: 1.5, ground: 0.95);

void _cursegullLeader(HdKit k, Canvas c, double r, double t) {
  const purple = Color(0xFFC8A0F0);
  const purpleD = Color(0xFF5A3A90);
  final flap = k.wave(t, 2);
  for (final s in const [-1.0, 1.0]) {
    c
      ..save()
      ..translate(s * r * 0.35, -r * 0.1)
      ..rotate(s * (-0.25 + flap * 0.35));
    final wing = Path()
      ..moveTo(0, -r * 0.15)
      ..quadraticBezierTo(s * r * 0.7, -r * 0.55, s * r * 1.2, -r * 0.4);
    // 찢긴 깃 끝(톱니)
    for (var i = 0; i < 4; i++) {
      final x = s * r * (1.2 - i * 0.22);
      wing
        ..lineTo(x - s * r * 0.05, -r * 0.12 + (i.isEven ? 0.08 : 0) * r)
        ..lineTo(x - s * r * 0.15, -r * 0.3);
    }
    wing
      ..lineTo(0, r * 0.15)
      ..close();
    k.blob(c, wing, purple, purpleD, gloss: false);
    c.restore();
  }
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.15), width: r * 0.95, height: r * 1.2));
  k
    ..blob(c, body, const Color(0xFFE4D0FA), purpleD)
    // 꼬리깃
    ..blob(
      c,
      Path()
        ..moveTo(-r * 0.2, r * 0.65)
        ..lineTo(0, r * 1.0)
        ..lineTo(r * 0.2, r * 0.65)
        ..close(),
      purple,
      purpleD,
      gloss: false,
    );
  // 머리 + 부리
  final head = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.55), width: r * 0.8, height: r * 0.72));
  k.blob(c, head, const Color(0xFFEFE0FF), purpleD);
  final open = (k.wave(t, 1) + 1) / 2;
  k
    ..blob(
      c,
      Path()
        ..moveTo(-r * 0.15, -r * 0.42)
        ..lineTo(0, -r * (0.15 - open * 0.04))
        ..lineTo(r * 0.15, -r * 0.42)
        ..close(),
      const Color(0xFFFFC84A),
      const Color(0xFFD87A1A),
      gloss: false,
      line: 0.6,
    )
    ..crown(c, Offset(0, -r * 0.86), r * 0.46);
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.18, -r * 0.6);
    k.eye(c, at, r * 0.24, angry: true);
    k.fill.color = const Color(0xAAFF2A4A); // 저주 붉은 눈빛
    c.drawCircle(at + Offset(0, r * 0.02), r * 0.05, k.fill);
  }
}

void _lavaTortoise(HdKit k, Canvas c, double r, double t) {
  const skin = Color(0xFFC8A070);
  const skinD = Color(0xFF6A4A2A);
  final nod = k.wave(t, 1) * r * 0.05;
  // 다리 4
  for (final (x, y) in const [(-0.8, 0.25), (0.8, 0.25), (-0.6, 0.65), (0.6, 0.65)]) {
    k.blob(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset(x * r, y * r), width: r * 0.42, height: r * 0.34)),
      skin,
      skinD,
      gloss: false,
    );
  }
  // 등껍질(현무암) + 용암 틈
  final shell = Path()
    ..moveTo(-r * 0.95, r * 0.4)
    ..cubicTo(-r * 1.0, -r * 0.75, r * 1.0, -r * 0.75, r * 0.95, r * 0.4)
    ..quadraticBezierTo(0, r * 0.62, -r * 0.95, r * 0.4)
    ..close();
  k.blob(c, shell, const Color(0xFF7A6A68), const Color(0xFF2E2424));
  final glow = 0.7 + 0.3 * (k.wave(t, 1, 1) + 1) / 2;
  final crack = Path()
    ..moveTo(0, -r * 0.55)
    ..lineTo(-r * 0.1, -r * 0.2)
    ..lineTo(-r * 0.55, -r * 0.05)
    ..moveTo(-r * 0.1, -r * 0.2)
    ..lineTo(r * 0.15, r * 0.1)
    ..lineTo(r * 0.6, -r * 0.1)
    ..moveTo(r * 0.15, r * 0.1)
    ..lineTo(r * 0.05, r * 0.4);
  k.limb(c, crack, Color.fromRGBO(255, (140 + 60 * glow).round(), 40, 1), r * 0.06);
  // 김(위로 올라가며 옅어짐)
  for (final (x, ph) in const [(-0.3, 0.0), (0.35, 0.5)]) {
    final u = (t / HdKit.loopMs + ph) % 1;
    k.fill.color = Color.fromRGBO(240, 230, 230, 0.6 * (1 - u));
    c.drawCircle(Offset(x * r, -r * (0.6 + u * 0.5)), r * (0.06 + u * 0.08), k.fill);
  }
  // 머리(앞으로 내민)
  final head = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.48 + nod), width: r * 0.62, height: r * 0.52));
  k.blob(c, head, const Color(0xFFE0BC8A), skinD);
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.15, r * 0.42 + nod), r * 0.22, angry: true);
  }
  k.smile(c, Offset(0, r * 0.6 + nod), r * 0.16);
}

void _sealChief(HdKit k, Canvas c, double r, double t) {
  const grey = Color(0xFFC0C8D4);
  const greyD = Color(0xFF55606E);
  final drum = k.wave(t, 2);
  final body = Path()
    ..moveTo(0, -r * 0.6)
    ..cubicTo(r * 0.8, -r * 0.6, r * 0.85, r * 0.6, r * 0.45, r * 0.85)
    ..lineTo(-r * 0.45, r * 0.85)
    ..cubicTo(-r * 0.85, r * 0.6, -r * 0.8, -r * 0.6, 0, -r * 0.6)
    ..close();
  k
    ..blob(c, body, const Color(0xFFDDE4EE), greyD)
    ..spots(c, r, const [
      (-0.45, 0.2, 0.06),
      (0.5, 0.35, 0.05),
      (-0.3, 0.6, 0.05),
      (0.35, 0.0, 0.04),
    ], const Color(0x6655606E));
  // 뒷지느러미(아래 양옆)
  for (final s in const [-1.0, 1.0]) {
    k
      ..blob(
        c,
        Path()
          ..moveTo(s * r * 0.2, r * 0.8)
          ..lineTo(s * r * 0.7, r * 1.0)
          ..lineTo(s * r * 0.35, r * 0.65)
          ..close(),
        grey,
        greyD,
        gloss: false,
      )
      // 앞지느러미(옆구리에서 파닥 — 배를 두드리듯)
      ..blob(
        c,
        Path()
          ..moveTo(s * r * 0.6, r * 0.05)
          ..quadraticBezierTo(s * r * (0.98 - drum * 0.1), r * 0.25, s * r * (0.85 - drum * 0.1), r * 0.5)
          ..quadraticBezierTo(s * r * 0.7, r * 0.42, s * r * 0.62, r * 0.35)
          ..close(),
        grey,
        greyD,
        gloss: false,
      );
  }
  // 얼굴: 큰 눈·코·수염
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.25, -r * 0.2), r * 0.3, angry: true);
  }
  k.spots(c, r, const [(0.0, 0.02, 0.07)], HdKit.inkColor);
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 0.4;
  for (final s in const [-1.0, 1.0]) {
    for (var i = -1; i <= 1; i++) {
      c.drawLine(
        Offset(s * r * 0.12, r * 0.08),
        Offset(s * r * 0.42, r * (0.04 + i * 0.07) + k.wave(t, 2, s) * r * 0.02),
        k.ink,
      );
    }
  }
  k.ink.strokeWidth = w;
  // 투구(철 + 뿔 하나)
  final helm = Path()
    ..moveTo(-r * 0.5, -r * 0.42)
    ..quadraticBezierTo(0, -r * 0.95, r * 0.5, -r * 0.42)
    ..quadraticBezierTo(0, -r * 0.55, -r * 0.5, -r * 0.42)
    ..close();
  k
    ..blob(c, helm, const Color(0xFFE8ECF4), const Color(0xFF7A8496))
    ..blob(
      c,
      Path()
        ..moveTo(-r * 0.06, -r * 0.72)
        ..lineTo(0, -r * 1.0)
        ..lineTo(r * 0.06, -r * 0.72)
        ..close(),
      const Color(0xFFFFE27A),
      const Color(0xFFD8901A),
      gloss: false,
      line: 0.6,
    );
}
