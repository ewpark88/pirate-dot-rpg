import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';

/// 해골 선원(td_enemy:skeleton — 부활·수면, docs/specs/economy-hd-monsters-b.md): 큰 해골 머리(2등신) + 해적 두건, 갈비뼈 사이 보라
/// 혼불(= 부활 심지), 녹슨 칼, 빈 눈구멍에 보라 불빛. 덜그럭 걸음 — 머리·팔이 따로 흔들린다.
const skeleton = HdSpecies(_skeleton, extent: 1.75, ground: 1.2);

/// 2등신 해골은 다른 종보다 작아 보여 1.2배로 그린다(S1 2026-10-17).
const _grow = 1.2;

const _bone = Color(0xFFF4ECD8);
const _boneD = Color(0xFFA89C84);
const _curse = Color(0xFFC07AFF);
const _bandana = Color(0xFFE04A5A);

void _skeleton(HdKit k, Canvas c, double r, double t) {
  c
    ..save()
    ..scale(_grow);
  _draw(k, c, r, t);
  c.restore();
}

void _draw(HdKit k, Canvas c, double r, double t) {
  final step = k.wave(t, 2);
  final rattle = k.wave(t, 4) * r * 0.03; // 머리 덜그럭
  final soul = (k.wave(t, 1) + 1) / 2;
  // 1) 다리 둘(번갈아)
  for (final s in const [-1.0, 1.0]) {
    k.limb(
      c,
      Path()
        ..moveTo(s * r * 0.15, r * 0.45)
        ..lineTo(s * r * (0.25 + 0.1 * step * s), r * 0.95),
      _bone,
      r * 0.12,
    );
  }
  // 2) 칼(오른손, 뒤) + 팔
  c
    ..save()
    ..translate(r * 0.55, r * 0.1)
    ..rotate(-0.5 + step * 0.25);
  k
    ..blob(
      c,
      Path()
        ..moveTo(-r * 0.05, 0)
        ..lineTo(r * 0.05, 0)
        ..lineTo(r * 0.04, -r * 0.85)
        ..lineTo(0, -r * 0.95)
        ..lineTo(-r * 0.04, -r * 0.85)
        ..close(),
      const Color(0xFFD8D0C0),
      const Color(0xFF8A6A4A),
      gloss: false,
      line: 0.6,
    )
    ..limb(
      c,
      Path()
        ..moveTo(-r * 0.12, 0)
        ..lineTo(r * 0.12, 0),
      const Color(0xFF8A5A2A),
      r * 0.08,
    );
  c.restore();
  for (final s in const [-1.0, 1.0]) {
    k.limb(
      c,
      Path()
        ..moveTo(s * r * 0.3, -r * 0.05)
        ..lineTo(s * r * 0.55, r * (0.12 - 0.08 * step * s)),
      _bone,
      r * 0.1,
    );
  }
  // 3) 갈비뼈 몸 + 혼불(가운데)
  final ribs = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.2), width: r * 0.7, height: r * 0.6));
  k.blob(c, ribs, _bone, _boneD, gloss: false);
  k.fill.color = _curse.withValues(alpha: 0.35 + 0.35 * soul);
  c.drawCircle(Offset(0, r * 0.22), r * (0.18 + 0.04 * soul), k.fill);
  for (var i = 0; i < 3; i++) {
    final y = r * (0.05 + i * 0.13);
    c.drawLine(Offset(-r * 0.28, y), Offset(r * 0.28, y), k.ink);
  }
  // 4) 큰 해골 머리 + 두건 + 빈 눈구멍(보라 불빛)
  final skull = Path()..addOval(Rect.fromCenter(center: Offset(rattle, -r * 0.5), width: r * 1.05, height: r * 0.95));
  k
    ..blob(c, skull, const Color(0xFFFFFAEE), _boneD)
    ..blob(
      c,
      Path()
        ..moveTo(-r * 0.55 + rattle, -r * 0.6)
        ..quadraticBezierTo(rattle, -r * 1.2, r * 0.55 + rattle, -r * 0.6)
        ..quadraticBezierTo(rattle, -r * 0.78, -r * 0.55 + rattle, -r * 0.6)
        ..close(),
      const Color(0xFFFF7A7A),
      _bandana,
    );
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.2 + rattle, -r * 0.45);
    if (k.mood == HdMood.hit) {
      k.squintEye(c, at, r * 0.28); // 맞음: 찡긋(잡몹 v2 — 눈구멍 대신)
      continue;
    }
    k.fill.color = HdKit.inkColor;
    c.drawOval(Rect.fromCenter(center: at, width: r * 0.28, height: r * 0.3), k.fill);
    k.fill.color = Color.lerp(_curse, const Color(0xFFFFFFFF), soul * 0.5)!;
    c.drawCircle(at + Offset(-r * 0.03, r * 0.02), r * 0.06, k.fill);
  }
  // 이빨 줄
  for (var i = 0; i < 4; i++) {
    final x = -r * 0.16 + i * r * 0.11 + rattle;
    c.drawLine(Offset(x, -r * 0.2), Offset(x, -r * 0.12), k.ink);
  }
}
