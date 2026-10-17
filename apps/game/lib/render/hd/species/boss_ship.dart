import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 배 보스 무리(S5 — 해적선·약탈선·유령선·쇄빙선·잠수함) 공용 몸: 정면 3/4(뱃머리가 이쪽 — 보스는 화면 위에서 배를 마주 본다).
/// 살아 있는 배: 뱃머리 위 화난 눈 2 + 이빨 같은 포문 줄(보스 표시), 뒤로 돛 2장(문양)·돛대 끝 깃발, 선체 판자 줄.
/// 잠수함(sub)은 돛 대신 둥근 함교 + 잠망경, 선체는 둥근 통. 종 파일은 [ShipLook]만 바꾼다(render-hd-style 보스 규격).
enum ShipEmblem { skull, lightning, snowflake, flame, ghost, anchor }

typedef ShipLook = ({
  Color hull,
  Color hullD,
  Color sail,
  Color sailD,
  Color flag,
  ShipEmblem emblem,
  bool sub,
  bool ghost,
  bool crown,
  bool ram,
});

void drawShipBoss(HdKit k, Canvas c, double r, double t, ShipLook look) {
  final rock = k.wave(t, 1) * 0.04; // 좌우로 흔들
  final bob = k.wave(t, 1, 1.5) * r * 0.04;
  c
    ..save()
    ..translate(0, bob)
    ..rotate(rock);
  if (look.sub) {
    _subTop(k, c, r, t, look);
  } else {
    _sails(k, c, r, t, look);
  }
  _hull(k, c, r, look);
  _face(k, c, r, t, look);
  c.restore();
}

/// 돛대 + 돛 2장(뒤 큰 돛·앞 작은 돛) + 깃발 + (보스) 돛대 끝 금관.
void _sails(HdKit k, Canvas c, double r, double t, ShipLook look) {
  final mast = Path()
    ..moveTo(-r * 0.05, r * 0.2)
    ..lineTo(-r * 0.05, -r * 1.02)
    ..lineTo(r * 0.05, -r * 1.02)
    ..lineTo(r * 0.05, r * 0.2)
    ..close();
  k.blob(c, mast, const Color(0xFF9A6A3A), const Color(0xFF5A3A1A), gloss: false, line: 0.6);
  final billow = k.wave(t, 2) * r * 0.04;
  // 큰 돛(바람에 부풀어 아래가 볼록).
  final big = Path()
    ..moveTo(-r * 0.75, -r * 0.88)
    ..quadraticBezierTo(0, -r * 0.98, r * 0.75, -r * 0.88)
    ..lineTo(r * 0.82 + billow, -r * 0.2)
    ..quadraticBezierTo(0, r * 0.02 + billow, -r * 0.82 - billow, -r * 0.2)
    ..close();
  k.blob(c, big, look.ghost ? look.sail.withValues(alpha: 0.75) : look.sail, look.sailD);
  _emblem(k, c, Offset(0, -r * 0.52), r * 0.24, look.emblem);
  // 깃발(돛대 끝, 펄럭).
  final wave = k.wave(t, 2, 0.8) * r * 0.05;
  final flag = Path()
    ..moveTo(-r * 0.05, -r * 0.98)
    ..lineTo(-r * 0.5, -r * 0.92 + wave)
    ..lineTo(-r * 0.05, -r * 0.8)
    ..close();
  k.blob(c, flag, look.flag, Color.lerp(look.flag, const Color(0xFF000000), 0.35)!, gloss: false, line: 0.6);
  if (look.crown) k.crown(c, Offset(0, -r * 0.92), r * 0.85); // 돛대 끝 큰 금관(깃발은 왼쪽으로 비켜) — 작으면 외곽선에 묻힌다
}

/// 잠수함 함교(둥근 탑) + 잠망경 + 앞 프로펠러 날 흔들.
void _subTop(HdKit k, Canvas c, double r, double t, ShipLook look) {
  final scope = Path()
    ..moveTo(r * 0.12, -r * 0.7)
    ..lineTo(r * 0.12, -r * 1.15)
    ..lineTo(r * 0.38, -r * 1.15)
    ..lineTo(r * 0.38, -r * 1.02)
    ..lineTo(r * 0.24, -r * 1.02)
    ..lineTo(r * 0.24, -r * 0.7)
    ..close();
  k.blob(c, scope, const Color(0xFFB8C0CC), const Color(0xFF6A7484), gloss: false, line: 0.6);
  final tower = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(-r * 0.42, -r * 0.82, r * 0.42, -r * 0.05), Radius.circular(r * 0.2)),
    );
  k.blob(c, tower, look.hull, look.hullD);
  _emblem(k, c, Offset(0, -r * 0.45), r * 0.2, look.emblem);
  if (look.crown) k.crown(c, Offset(-r * 0.05, -r * 0.8), r * 0.7);
}

/// 선체: 정면 3/4 — 위가 넓고 아래가 좁은 배 모양(잠수함은 둥근 통), 판자 줄 2개, 앞이 뾰족(충각 ram).
void _hull(HdKit k, Canvas c, double r, ShipLook look) {
  final Path hull;
  if (look.sub) {
    hull = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.35), width: r * 2.1, height: r * 1.0));
  } else {
    hull = Path()
      ..moveTo(-r * 1.15, -r * 0.15)
      ..quadraticBezierTo(0, -r * 0.02, r * 1.15, -r * 0.15)
      ..quadraticBezierTo(r * 1.0, r * 0.75, 0, r * 0.95)
      ..quadraticBezierTo(-r * 1.0, r * 0.75, -r * 1.15, -r * 0.15)
      ..close();
  }
  k.blob(c, hull, look.ghost ? look.hull.withValues(alpha: 0.8) : look.hull, look.hullD);
  if (!look.sub) {
    // 판자 줄(외곽선 얇게).
    final w = k.ink.strokeWidth;
    k.ink.strokeWidth = w * 0.45;
    for (final y in const [0.18, 0.45]) {
      c.drawPath(
        Path()
          ..moveTo(-r * (1.05 - y * 0.35), r * y)
          ..quadraticBezierTo(0, r * (y + 0.12), r * (1.05 - y * 0.35), r * y),
        k.ink,
      );
    }
    k.ink.strokeWidth = w;
  }
  if (look.ram) {
    // 충각(쇄빙): 뱃머리 아래 금속 쐐기.
    final ram = Path()
      ..moveTo(-r * 0.32, r * 0.62)
      ..lineTo(0, r * 1.18)
      ..lineTo(r * 0.32, r * 0.62)
      ..close();
    k.blob(c, ram, const Color(0xFFE8F2FA), const Color(0xFF8AA0B8), line: 0.7);
  }
}

/// 얼굴(보스 표시): 화난 눈 2 + 이빨 같은 포문 줄.
void _face(HdKit k, Canvas c, double r, double t, ShipLook look) {
  final y = look.sub ? r * 0.25 : r * 0.12;
  k
    ..eye(c, Offset(-r * 0.42, y), r * 0.42, angry: true)
    ..eye(c, Offset(r * 0.42, y), r * 0.42, angry: true);
  // 입 = 포문 줄: 고리에 한 번 벌렸다 닫음.
  final open = (k.wave(t, 1) + 1) * 0.5 * r * 0.06;
  final my = y + r * 0.42;
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.5, my)
      ..quadraticBezierTo(0, my + r * 0.3 + open, r * 0.5, my)
      ..close(),
  );
  for (var i = 0; i < 4; i++) {
    k.tooth(c, Offset(-r * 0.42 + i * r * 0.21, my + r * 0.01), r * 0.17, r * 0.15);
  }
}

/// 돛 문양(외곽선 얇게).
void _emblem(HdKit k, Canvas c, Offset at, double s, ShipEmblem e) {
  final Path p;
  var light = const Color(0xFFFFFFFF);
  var dark = const Color(0xFFC8D0DC);
  switch (e) {
    case ShipEmblem.lightning:
      p = Path()
        ..moveTo(at.dx + s * 0.15, at.dy - s)
        ..lineTo(at.dx - s * 0.45, at.dy + s * 0.1)
        ..lineTo(at.dx - s * 0.02, at.dy + s * 0.1)
        ..lineTo(at.dx - s * 0.2, at.dy + s)
        ..lineTo(at.dx + s * 0.45, at.dy - s * 0.15)
        ..lineTo(at.dx + s * 0.02, at.dy - s * 0.15)
        ..close();
      light = const Color(0xFFFFE24A);
      dark = const Color(0xFFE0A000);
    case ShipEmblem.flame:
      p = Path()
        ..moveTo(at.dx, at.dy - s)
        ..quadraticBezierTo(at.dx + s * 0.8, at.dy - s * 0.1, at.dx + s * 0.45, at.dy + s * 0.75)
        ..quadraticBezierTo(at.dx, at.dy + s, at.dx - s * 0.45, at.dy + s * 0.75)
        ..quadraticBezierTo(at.dx - s * 0.8, at.dy - s * 0.1, at.dx, at.dy - s)
        ..close();
      light = const Color(0xFFFFC23A);
      dark = const Color(0xFFE5502A);
    case ShipEmblem.snowflake:
      // 눈송이: 세 갈래 막대(외곽선 둘린 줄) — blob 대신 limb로 그리고 끝낸다.
      for (var i = 0; i < 3; i++) {
        final a = i * math.pi / 3 + math.pi / 2;
        final d = Offset(math.cos(a), math.sin(a)) * s;
        k.limb(c, Path()..addPolygon([at - d, at + d], false), const Color(0xFFE8F8FF), s * 0.2);
      }
      return;
    case ShipEmblem.ghost:
      p = Path()
        ..moveTo(at.dx - s * 0.6, at.dy + s * 0.8)
        ..lineTo(at.dx - s * 0.6, at.dy - s * 0.1)
        ..quadraticBezierTo(at.dx, at.dy - s * 1.2, at.dx + s * 0.6, at.dy - s * 0.1)
        ..lineTo(at.dx + s * 0.6, at.dy + s * 0.8)
        ..lineTo(at.dx + s * 0.3, at.dy + s * 0.55)
        ..lineTo(at.dx, at.dy + s * 0.8)
        ..lineTo(at.dx - s * 0.3, at.dy + s * 0.55)
        ..close();
      light = const Color(0xFFE8FFF6);
      dark = const Color(0xFF9AE0C8);
    case ShipEmblem.anchor:
      p = Path()
        ..addOval(Rect.fromCircle(center: at + Offset(0, -s * 0.7), radius: s * 0.22))
        ..addRect(Rect.fromCenter(center: at, width: s * 0.2, height: s * 1.3))
        ..addRect(Rect.fromCenter(center: at + Offset(0, -s * 0.3), width: s * 0.8, height: s * 0.18))
        ..addArc(Rect.fromCircle(center: at + Offset(0, s * 0.2), radius: s * 0.6), 0.3, 2.5);
      light = const Color(0xFFFFE27A);
      dark = const Color(0xFFE0A020);
    case ShipEmblem.skull:
      p = Path()
        ..addOval(Rect.fromCenter(center: at + Offset(0, -s * 0.15), width: s * 1.3, height: s * 1.15))
        ..addRect(Rect.fromCenter(center: at + Offset(0, s * 0.55), width: s * 0.75, height: s * 0.4));
  }
  k.blob(c, p, light, dark, gloss: false, line: 0.5);
  if (e == ShipEmblem.skull) {
    k.fill.color = HdKit.inkColor;
    c
      ..drawCircle(at + Offset(-s * 0.28, -s * 0.15), s * 0.2, k.fill)
      ..drawCircle(at + Offset(s * 0.28, -s * 0.15), s * 0.2, k.fill);
  }
}
