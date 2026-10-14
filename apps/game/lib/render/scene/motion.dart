import 'dart:math' as math;

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/transients.dart';

/// 일시 객체의 움직임 계산 (장면이 매 프레임 부른다).

const _skipBounces = 3;
const _fountainEnd = 0.4;
const _fountainSpreadPx = 10;

/// 진행률([Projectile.progress])에 맞춰 발사체 위치를 정한다.
void placeProjectile(Projectile p) {
  final t = p.progress;
  final s = p.style;
  switch (s.path) {
    case ProjectilePath.drop:
      p
        ..x = p.toX
        ..y = p.toY - s.arcPx * (1 - t);
    case ProjectilePath.line || ProjectilePath.arc || ProjectilePath.skip:
      p
        ..x = p.fromX + (p.toX - p.fromX) * t
        ..y = p.fromY + (p.toY - p.fromY) * t;
      if (s.path == ProjectilePath.arc) p.y -= s.arcPx * 4 * t * (1 - t);
      if (s.path == ProjectilePath.skip) p.y -= s.arcPx * math.sin(t * math.pi * _skipBounces).abs();
  }
}

/// 코인: 분수처럼 튀었다가(앞 40%) 배로 빨려간다.
void moveCoin(Coin c) {
  final t = (c.ageMs / c.flyMs).clamp(0.0, 1.0);
  if (t < _fountainEnd) {
    final f = t / _fountainEnd;
    c
      ..x = c.fromX + c.spread * _fountainSpreadPx * f
      ..y = c.fromY - c.lift * math.sin(f * math.pi);
  } else {
    final f = (t - _fountainEnd) / (1 - _fountainEnd);
    final sx = c.fromX + c.spread * _fountainSpreadPx;
    final ease = f * f;
    c
      ..x = sx + (c.toX - sx) * ease
      ..y = c.fromY + (c.toY - c.fromY) * ease;
  }
}

/// 이펙트: 지연 뒤 시작하고, 쓸고 지나가는 패턴이면 x가 움직인다.
void moveEffect(Effect e) {
  final t = e.ageMs - e.delayMs;
  e.x = e.startX + e.vx * (t > 0 ? t : 0);
}
