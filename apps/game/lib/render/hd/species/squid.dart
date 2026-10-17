import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 오징어(td_enemy:squid — 기본·수중, docs/specs/economy-hd-monsters-b.md): 세모 머리 지느러미, 분홍 몸에 흰 반점, 다리 6,
/// 큰 흰 멍한 눈. 다리를 오므렸다 펴며 위로 쭉 나아간다.
const squid = HdSpecies(_squid, extent: 1.5, ground: 0.95);

const _pink = Color(0xFFFF7AB8);
const _pinkD = Color(0xFFB02A6A);

void _squid(HdKit k, Canvas c, double r, double t) {
  final pump = (k.wave(t, 1) + 1) / 2; // 0 펴짐 ~ 1 오므림
  final rise = -pump * r * 0.12;
  // 1) 다리 6(오므리면 모이고 짧아짐)
  for (var i = 0; i < 6; i++) {
    final u = (i - 2.5) / 2.5;
    final a = math.pi / 2 + u * (0.55 - pump * 0.35);
    k.tentacle(
      c,
      Offset(u * r * 0.38, r * 0.35 + rise),
      a,
      r * (0.95 - pump * 0.25),
      2 * math.pi * t / HdKit.loopMs + i,
      i.isEven ? _pink : const Color(0xFFE85A9A),
      r * 0.15,
    );
  }
  // 2) 머리 지느러미(세모 둘)
  for (final s in const [-1.0, 1.0]) {
    k.blob(
      c,
      Path()
        ..moveTo(s * r * 0.2, -r * 0.85 + rise)
        ..lineTo(s * r * (0.75 + 0.05 * k.wave(t, 2)), -r * 0.55 + rise)
        ..lineTo(s * r * 0.35, -r * 0.25 + rise)
        ..close(),
      _pink,
      _pinkD,
      gloss: false,
      line: 0.7,
    );
  }
  // 3) 몸(세로로 긴 물방울)
  final body = Path()
    ..moveTo(0, -r * 1.05 + rise)
    ..cubicTo(r * 0.7, -r * 0.7 + rise, r * 0.6, r * 0.45 + rise, 0, r * 0.45 + rise)
    ..cubicTo(-r * 0.6, r * 0.45 + rise, -r * 0.7, -r * 0.7 + rise, 0, -r * 1.05 + rise)
    ..close();
  k
    ..blob(c, body, const Color(0xFFFFA8D0), _pinkD)
    ..spots(c, r, [(-0.22, -0.55, 0.06), (0.25, -0.35, 0.05), (-0.05, -0.75, 0.04)], const Color(0x99FFFFFF))
    ..underwater(c, body); // 얼굴보다 먼저 — 눈이 흐려지지 않게
  c.translate(0, rise);
  // 4) 큰 멍한 눈(눈동자 가운데) + 작은 입
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.24, -r * 0.05), r * 0.36);
  }
  k.smile(c, Offset(0, r * 0.22), r * 0.12);
  c.translate(0, -rise);
  k.bubbles(c, r, t);
}
