import 'dart:math' as math;

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 일시 객체의 움직임 계산 (장면이 매 프레임 부른다).

const _skipBounces = 3;
const _fountainEnd = 0.5;
const _hopSpeedX = 25.0;
const _hopLiftBase = 30.0;
const _gravityHalf = 100.0;

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
  if (c.fallPx > 0) {
    _rainCoin(c, t);
    return;
  }
  final hop = math.min(t, _fountainEnd) * c.flyMs / Duration.millisecondsPerSecond;
  final hx = c.fromX + c.spread * _hopSpeedX * hop;
  final hy = c.fromY - (_hopLiftBase + c.lift) * hop + _gravityHalf * hop * hop;
  if (t < _fountainEnd) {
    c
      ..x = hx
      ..y = hy;
  } else {
    final f = (t - _fountainEnd) / (1 - _fountainEnd);
    final ease = 1 - (1 - f) * (1 - f);
    c
      ..x = hx + (c.toX - hx) * ease
      ..y = hy + (c.toY - hy) * ease;
  }
}

const _rainFallEnd = 0.5;

/// 코인 비: 앞 절반은 곧장 떨어지고, 뒤 절반은 배로 빨려간다.
void _rainCoin(Coin c, double t) {
  if (t < _rainFallEnd) {
    c
      ..x = c.fromX
      ..y = c.fromY + c.fallPx * (t / _rainFallEnd);
    return;
  }
  final f = (t - _rainFallEnd) / (1 - _rainFallEnd);
  final ease = f * f;
  final sy = c.fromY + c.fallPx;
  c
    ..x = c.fromX + (c.toX - c.fromX) * ease
    ..y = sy + (c.toY - sy) * ease;
}

/// 이펙트: 지연 뒤 시작하고, 쓸고 지나가는 패턴이면 x가 움직인다.
void moveEffect(Effect e) {
  final t = e.ageMs - e.delayMs;
  e.x = e.startX + e.vx * (t > 0 ? t : 0);
}

bool _projectileDone(Projectile p) => p.progress >= 1;
bool _hitDone(HitState h) => h.flashMs <= 0 && h.knockAgeMs >= h.knockMs;

/// 발사체 진행률: 재생기의 표시 위치로 정한다(히트스톱 구간은 멈춤).
void updateProjectiles(BattleScene s) {
  final player = s.player;
  final pos = player.position;
  for (final p in s.projectiles.active) {
    if (pos < p.startIndex) {
      p.progress = 0;
      continue;
    }
    final total = player.motionBetween(p.startIndex, p.impactIndex);
    p.progress = total <= 0 ? 1 : (player.motionBetween(p.startIndex, pos) / total).clamp(0.0, 1.0);
    placeProjectile(p);
  }
  s.projectiles.releaseWhere(_projectileDone);
}

/// 맞은 적의 흰 번쩍임·넉백을 보간 위치에 얹는다.
void applyHits(BattleScene s, double dtMs) {
  for (final h in s.hits.active) {
    if (h.flashMs > 0) h.flashMs -= dtMs;
    if (h.knockAgeMs < h.knockMs) h.knockAgeMs += dtMs;
  }
  s.hits.releaseWhere(_hitDone);
  for (var k = 0; k < s.poseCount; k++) {
    final pose = s.poses[k];
    if (pose.boss) {
      pose
        ..x = s.clampBossX(pose.x)
        ..drawX = pose.x;
    }
    for (final h in s.hits.active) {
      if (h.id != pose.id) continue;
      pose.flash = s.settings.flash && h.flashMs > 0;
      if (h.knockMs > 0 && h.knockAgeMs < h.knockMs) {
        final push = h.px * (1 - h.knockAgeMs / h.knockMs);
        pose
          ..drawX = pose.x + h.dirX * push
          ..drawY = pose.y + h.dirY * push;
      }
    }
  }
}
