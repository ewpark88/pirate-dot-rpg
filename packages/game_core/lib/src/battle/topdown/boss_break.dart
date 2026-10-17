import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/engine/events.dart';

/// 보스 브레이크 게이지 (사용자 결정 2026-10-17 — '기절·끌기·취약·둔화가 들어갈 때마다 쌓이고, 가득 차면 보스가 쓰러져 몇 초간 피해 ×3').
/// skills.json bossBreak {stunPerSec, slowPerSec, vulnerablePerSec, pullPerPx, breakSec, damageMul}(없으면 꺼짐):
/// 이번 틱 보스에 늘어난 기절·둔화·취약 초와 밀림·끌림 거리를 게이지로. 가득(1)이면 breakSec 동안 기절 + 받는 피해 × damageMul
/// (취약 = damageMul − 1, 기존 피해 길 그대로). 쓰러진 동안은 쌓이지 않는다.
/// cooldownSec(선택, 없으면 0 — S1 승인 2026-10-17): 일어난 뒤 그 초 동안도 안 쌓인다 — 센 제어 편성도 30초에 몇 번에서 멈추게.
/// 보스 첫 등장 직후엔 쿨다운이 없다(첫 브레이크는 빨리 보이게).
extension BossBreak on Round {
  void tickBossBreak() {
    final skills = t.skills.raw;
    final on = skills.has('bossBreak');
    for (final e in field.living) {
      if (!e.boss) continue;
      final gained = !on
          ? 0.0
          : () {
              final b = skills.obj('bossBreak');
              return e.breakStun * b.numberOr('stunPerSec', 0) +
                  e.breakSlow * b.numberOr('slowPerSec', 0) +
                  e.breakVulnerable * b.numberOr('vulnerablePerSec', 0) +
                  e.breakPull * b.numberOr('pullPerPx', 0);
            }();
      e
        ..breakStun = 0
        ..breakSlow = 0
        ..breakVulnerable = 0
        ..breakPull = 0;
      if (e.brokenUntil > 0) {
        if (ctx.tick >= e.brokenUntil) {
          e.brokenUntil = 0; // 다시 일어남
          final cool = skills.obj('bossBreak').numberOr('cooldownSec', 0);
          if (cool > 0) {
            e
              ..breakCooldownTicks = math.max(1, (cool / dt).round())
              ..breakCooldownUntil = ctx.tick + e.breakCooldownTicks;
          }
        }
        continue;
      }
      e.breakCooldownRatio = ctx.tick < e.breakCooldownUntil
          ? (e.breakCooldownUntil - ctx.tick) / e.breakCooldownTicks
          : 0;
      if (ctx.tick < e.breakCooldownUntil) continue;
      if (ctx.tick < e.staggerUntil) continue; // 층 깨짐 비틀 중엔 안 쌓인다(boss-feel — 겹쳐 녹는 것 막기)
      e.breakGauge = math.min(1, e.breakGauge + gained);
      if (e.breakGauge < 1) continue;
      final b = skills.obj('bossBreak');
      final sec = b.number('breakSec');
      final ticks = math.max(1, (sec / dt).round());
      e
        ..breakGauge = 0
        ..brokenUntil = ctx.tick + ticks
        ..stunTimer = math.max(e.stunTimer, sec)
        ..vulnerable = math.max(e.vulnerable, b.number('damageMul') - 1)
        ..vulnerableTimer = math.max(e.vulnerableTimer, sec)
        ..breakStun = 0
        ..breakVulnerable = 0; // 쓰러뜨린 기절·취약은 게이지에 다시 안 쌓는다
      ctx.emit(BossBroken(ctx.tick, enemyId: e.id, ticks: ticks, x: e.x, y: e.y));
    }
  }
}
