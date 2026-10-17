import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 빙하 예티(td_boss:frost_yeti, 빙하 순환 v2): 유빙 위 흰 털 설인 — 푸른 얼굴, 얼음 몽둥이를 치켜든다.
const frostYeti = HdSpecies(_frostYeti, extent: 1.5, ground: 1.05);

/// 얼음 일각고래(td_boss:ice_narwhal): 하늘색 일각고래, 수정 뿔이 반짝이며 몸을 튼다.
const iceNarwhal = HdSpecies(_iceNarwhal, extent: 1.55, ground: 1);

/// 눈부엉이 범선(td_boss:snow_owl_ship): 하얀 선체·눈 돛, 뱃머리에 부엉이 얼굴 — 배 보스 공용 몸.
const snowOwlShip = HdSpecies(_snowOwlShip, extent: 1.3, ground: 0.95);

const ShipLook _owlLook = (
  hull: Color(0xFFF2F6FA),
  hullD: Color(0xFF8AA0B8),
  sail: Color(0xFFFFFFFF),
  sailD: Color(0xFFC8DCEC),
  flag: Color(0xFFFFC23A),
  emblem: ShipEmblem.snowflake,
  sub: false,
  ghost: false,
  crown: false,
  ram: false,
  patch: false,
);

void _snowOwlShip(HdKit k, Canvas c, double r, double t) {
  drawShipBoss(k, c, r, t, _owlLook);
  // 뱃머리 부엉이 얼굴: 귀깃 두 개 + 큰 둥근 눈(표정 공용)
  final bob = k.wave(t, 1, 1.5) * r * 0.04 + r * 0.1;
  for (final s in const [-1.0, 1.0]) {
    k.blob(
      c,
      Path()
        ..moveTo(s * r * 0.15, -r * 1.05 + bob)
        ..lineTo(s * r * 0.45, -r * 1.3 + bob)
        ..lineTo(s * r * 0.45, -r * 0.95 + bob)
        ..close(),
      const Color(0xFFF2F6FA),
      const Color(0xFF8AA0B8),
      gloss: false,
    );
  }
  final face = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.85 + bob), width: r * 0.95, height: r * 0.66));
  k
    ..blob(c, face, const Color(0xFFFFFFFF), const Color(0xFF8AA0B8))
    ..eye(c, Offset(-r * 0.2, -r * 0.88 + bob), r * 0.3, angry: true)
    ..eye(c, Offset(r * 0.2, -r * 0.88 + bob), r * 0.3, angry: true);
  k.fill.color = const Color(0xFFFFB43A);
  c.drawPath(
    Path()
      ..moveTo(-r * 0.07, -r * 0.74 + bob)
      ..lineTo(r * 0.07, -r * 0.74 + bob)
      ..lineTo(0, -r * 0.6 + bob)
      ..close(),
    k.fill,
  );
}

void _frostYeti(HdKit k, Canvas c, double r, double t) {
  const fur = Color(0xFFFFFFFF);
  const furD = Color(0xFF9AB4CC);
  final bob = k.wave(t, 1) * r * 0.03;
  final swing = k.wave(t, 1, 1) * 0.35;
  // 유빙
  k.blob(
    c,
    Path()
      ..moveTo(-r * 1.0, r * 0.6)
      ..lineTo(-r * 0.6, r * 0.45)
      ..lineTo(r * 0.7, r * 0.42)
      ..lineTo(r * 1.0, r * 0.62)
      ..lineTo(r * 0.5, r * 0.85)
      ..lineTo(-r * 0.7, r * 0.82)
      ..close(),
    const Color(0xFFE8F8FF),
    const Color(0xFF6AA8D8),
    gloss: false,
  );
  // 다리·몸·팔
  for (final s in const [-1.0, 1.0]) {
    k.blob(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset(s * r * 0.3, r * 0.45 + bob), width: r * 0.42, height: r * 0.3)),
      fur,
      furD,
    );
  }
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.05 + bob), width: r * 1.3, height: r * 1.0));
  k
    ..blob(c, body, fur, furD)
    ..limb(
      c,
      Path()
        ..moveTo(-r * 0.55, -r * 0.05 + bob)
        ..quadraticBezierTo(-r * 0.85, r * 0.15, -r * 0.7, r * 0.35 + bob),
      const Color(0xFFE8F0FA),
      r * 0.22,
    );
  // 몽둥이 든 팔(오른쪽, 휘두름)
  final hand = Offset(r * (0.75 + swing * 0.2), -r * (0.55 + swing * 0.3) + bob);
  k.limb(
    c,
    Path()
      ..moveTo(r * 0.55, -r * 0.05 + bob)
      ..quadraticBezierTo(r * 0.85, -r * 0.1 + bob, hand.dx, hand.dy),
    const Color(0xFFE8F0FA),
    r * 0.22,
  );
  c
    ..save()
    ..translate(hand.dx, hand.dy)
    ..rotate(-0.5 + swing);
  k.blob(
    c,
    Path()
      ..moveTo(-r * 0.08, 0)
      ..lineTo(-r * 0.16, -r * 0.6)
      ..lineTo(r * 0.16, -r * 0.6)
      ..lineTo(r * 0.08, 0)
      ..close(),
    const Color(0xFFBDEBFF),
    const Color(0xFF4A90C8),
  );
  c.restore();
  // 얼굴(푸른 피부) + 눈 + 송곳니 입
  final face = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.3 + bob), width: r * 0.7, height: r * 0.55));
  k
    ..blob(c, face, const Color(0xFF9AD0F0), const Color(0xFF3A78A8))
    ..eye(c, Offset(-r * 0.14, -r * 0.38 + bob), r * 0.2, angry: true)
    ..eye(c, Offset(r * 0.14, -r * 0.38 + bob), r * 0.2, angry: true)
    ..mouth(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.15 + bob), width: r * 0.3, height: r * 0.14)),
    )
    ..tooth(c, Offset(-r * 0.08, -r * 0.2 + bob), r * 0.07, r * 0.09)
    ..tooth(c, Offset(r * 0.08, -r * 0.2 + bob), r * 0.07, r * 0.09);
}

void _iceNarwhal(HdKit k, Canvas c, double r, double t) {
  const ice = Color(0xFFA8E0F8);
  const iceD = Color(0xFF3A7AB0);
  final bend = k.wave(t, 1) * 0.12;
  final bob = k.wave(t, 1, 1) * r * 0.04;
  c
    ..save()
    ..translate(0, bob)
    ..rotate(bend * 0.3);
  k.tail(c, Offset(r * 0.95, r * 0.05), r * 0.5, k.wave(t, 2) * 0.35, ice, iceD);
  final body = Path()..addOval(Rect.fromCenter(center: Offset(r * 0.05, r * 0.05), width: r * 1.85, height: r * 0.95));
  k
    ..blob(c, body, const Color(0xFFC8F0FF), iceD)
    ..spots(c, r, const [(0.3, -0.15, 0.07), (0.55, 0.0, 0.05), (0.1, -0.25, 0.05)], const Color(0x553A7AB0));
  // 수정 뿔(앞으로 길게) + 반짝
  final horn = Path()
    ..moveTo(-r * 0.7, -r * 0.26)
    ..lineTo(-r * 1.38, -r * 0.42)
    ..lineTo(-r * 0.76, r * 0.16)
    ..close();
  k.blob(c, horn, const Color(0xFFFFFFFF), const Color(0xFF6AB8E8));
  final tw = (k.wave(t, 2) + 1) / 2;
  k.fill.color = Color.fromRGBO(255, 255, 255, tw);
  final tip = Offset(-r * 1.3, -r * 0.4);
  c
    ..drawCircle(tip, r * 0.05 * (0.5 + tw), k.fill)
    ..restore();
  k
    ..eye(c, Offset(-r * 0.45, -r * 0.08 + bob), r * 0.26, angry: true)
    ..mouth(
      c,
      Path()
        ..moveTo(-r * 0.8, r * 0.15 + bob)
        ..quadraticBezierTo(-r * 0.55, r * 0.28 + bob, -r * 0.3, r * 0.18 + bob)
        ..lineTo(-r * 0.3, r * 0.22 + bob)
        ..quadraticBezierTo(-r * 0.55, r * 0.34 + bob, -r * 0.8, r * 0.2 + bob)
        ..close(),
    );
}
