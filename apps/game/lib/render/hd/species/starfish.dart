import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 불가사리(td_enemy:starfish — 분열·수중·원거리 가시, docs/specs/economy-hd-monsters-b.md): 팔 끝 가시 5, 양옆 팔 사이 용암 금
/// (쪼개질 자리), 쏘기 전 위 팔이 달아오름, 째려보는 큰 눈. 흔들흔들 돌며 들썩·팔이 오므렸다 펴진다.
const starfish = HdSpecies(_starfish, extent: 1.45, ground: 0.8);

void _starfish(HdKit k, Canvas c, double r, double t) => paintStarfish(k, c, r, t, small: false);

const _orange = Color(0xFFFFB04A);
const _orangeD = Color(0xFFD8601E);
const _lava = Color(0xFFFF4A2A);

/// 팔 [i]의 방향(위 팔 = 0, 시계 방향).
double _arm(int i) => -math.pi / 2 + i * 2 * math.pi / 5;

/// 큰 것·작은 것(starfish_small.dart)이 같이 쓴다. 작은 것 = 둥글고 짧은 팔·금·가시 없음·동그란 눈·빨리 돎.
void paintStarfish(HdKit k, Canvas c, double r, double t, {required bool small}) {
  final spin = k.wave(t, small ? 2 : 1) * (small ? 0.5 : 0.18);
  final bob = k.wave(t, 2, 0.5) * r * 0.06;
  final flex = 1 + k.wave(t, 2) * 0.06; // 팔 길이 오므림·폄
  final inner = small ? 0.55 : 0.42; // 팔 사이 오목한 곳(반지름 비율)
  final tipR = small ? 0.22 : 0.16; // 팔 끝 둥글기
  // 쏘기 전 달아오르는 위 팔(한 고리 끝 무렵 가장 밝게).
  final glow = small ? 0.0 : math.pow((k.wave(t, 1, -math.pi / 2) + 1) / 2, 3).toDouble();

  c
    ..save()
    ..translate(0, bob)
    ..rotate(spin);
  // 팔 i 끝의 왼쪽(-1)·오른쪽(+1) 점.
  Offset tipSide(int i, double side) {
    final a = _arm(i);
    return Offset(math.cos(a), math.sin(a)) * r * flex + Offset(-math.sin(a), math.cos(a)) * r * tipR * side;
  }

  final star = Path();
  for (var i = 0; i < 5; i++) {
    final b = _arm(i) + math.pi / 5;
    final valley = Offset(math.cos(b), math.sin(b)) * r * inner * 1.05;
    final from = tipSide(i, -1);
    final to = tipSide(i, 1);
    final next = tipSide((i + 1) % 5, -1);
    if (i == 0) star.moveTo(from.dx, from.dy);
    star
      ..arcToPoint(to, radius: Radius.circular(r * tipR))
      ..quadraticBezierTo(valley.dx, valley.dy, next.dx, next.dy);
  }
  star.close();
  // 1) 팔 끝 가시(큰 것만, 몸 뒤)
  if (!small) {
    for (var i = 0; i < 5; i++) {
      final d = Offset(math.cos(_arm(i)), math.sin(_arm(i))) * flex;
      final n = Offset(-d.dy, d.dx);
      final a = d * r * 0.85 + n * r * 0.2;
      final tip = d * r * 1.3;
      final b = d * r * 0.85 - n * r * 0.2;
      final heat = i == 0 ? glow : 0.0;
      k.blob(
        c,
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(b.dx, b.dy)
          ..close(),
        Color.lerp(const Color(0xFFFFE9B0), const Color(0xFFFFE070), heat)!,
        Color.lerp(const Color(0xFFE8862E), _lava, heat)!,
        gloss: false,
        line: 0.6,
      );
    }
  }
  // 2) 몸
  k.blob(c, star, small ? const Color(0xFFFFC870) : _orange, _orangeD);
  if (glow > 0.05) {
    k.fill.color = _lava.withValues(alpha: 0.75 * glow);
    c.drawCircle(Offset(0, -r * 0.78 * flex), r * 0.17, k.fill);
  }
  // 3) 용암 금(양옆 팔 사이 오목한 곳에서 안쪽으로 번개꼴 — 얼굴은 비운다)
  if (!small) {
    final hot = Color.lerp(const Color(0xFFFF7A2A), const Color(0xFFFFE070), (k.wave(t, 2) + 1) / 2)!;
    for (final i in const [1, 3]) {
      final b = _arm(i) + math.pi / 5;
      final d = Offset(math.cos(b), math.sin(b));
      final n = Offset(-d.dy, d.dx);
      final p0 = d * r * inner * 1.02;
      final p1 = d * r * 0.62 + n * r * 0.07;
      final p2 = d * r * 0.5 - n * r * 0.05;
      k.limb(
        c,
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy),
        hot,
        k.ink.strokeWidth * 0.8,
      );
    }
  }
  // 4) 수중 물빛 + 등 돌기
  k
    ..underwater(c, star)
    ..spots(c, r, [
      for (var i = 0; i < 5; i++) (math.cos(_arm(i)) * 0.55, math.sin(_arm(i)) * 0.55, 0.05),
    ], const Color(0x66FFF0C8));
  c.restore();
  // 5) 얼굴(돌지 않음, 들썩만)
  if (small) {
    for (final s in const [-1.0, 1.0]) {
      k.eye(c, Offset(s * r * 0.2, -r * 0.05 + bob), r * 0.32);
    }
  } else {
    for (final s in const [-1.0, 1.0]) {
      k.eye(c, Offset(s * r * 0.19, -r * 0.1 + bob), r * 0.3, angry: true, look: -s * 0.4);
    }
    c.drawPath(
      Path()
        ..moveTo(-r * 0.1, r * 0.2 + bob)
        ..quadraticBezierTo(0, r * 0.12 + bob, r * 0.1, r * 0.2 + bob),
      k.ink,
    );
  }
  k.bubbles(c, r, t);
}
