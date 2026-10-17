import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// 보스전 손맛 (사용자 '보스전도 너무 밋밋해' 2026-10-17, S1 승인 설계 boss-feel):
// ① 체력 층 waves.boss.bars — 층이 깨질 때 BossBarBroken + 짧은 비틀(기절 staggerSec · 받는 피해 × staggerDamageMul).
//    브레이크(skills.bossBreak, 피해 × 3)와 별개, 비틀 동안은 브레이크 게이지가 안 쌓인다(겹쳐 녹는 것 막기).
// ② 선장 필살기 meta.captainSkill — 게이지가 처치·보스 피해로 차고, 가득이면 자동(Settings.autoUltimate) 또는
//    TriggerUltimate로: 선장 궁극기 효과(피버 첫 일격과 같은 castUltimate) + 함대 rushSec초 폭주(공격 속도 × attackSpeedMul).

/// HP 비율 [ratio]에서 남은 층 수(최소 1): 깎인 층 수를 내림해 뺀다 — 딱 경계(2/3 등)면 그 층은 깨진 것.
int bossBarsLeftAt(int bars, double ratio) => math.max(1, bars - ((1 - ratio) * bars).floor());

/// 스테이지 [stage] 보스의 체력 층 수(waves.boss.bars.byStage — from 이상 중 마지막). 표에 없으면 1(층 없음).
int bossBarsAt(GameTables t, int stage) {
  final b = t.waves.raw.obj('boss');
  if (!b.has('bars')) return 1;
  var n = 1;
  for (final row in b.obj('bars').objs('byStage')) {
    if (stage >= row.integer('from')) n = row.integer('count');
  }
  return n;
}

extension BossFeel on Round {
  JsonReader? get _bars => t.waves.raw.obj('boss').has('bars') ? t.waves.raw.obj('boss').obj('bars') : null;

  /// 매 틱(피해가 들어간 뒤): 보스 남은 층이 줄었으면 BossBarBroken(층마다) + 비틀. 마지막 층(처치)은 이벤트 없음.
  void tickBossBars() {
    final bars = _bars;
    if (bars == null) return;
    for (final e in field.foes) {
      if (!e.boss || e.bossBars <= 1) continue;
      if (!e.alive) continue;
      final left = bossBarsLeftAt(e.bossBars, (e.hp / e.maxHp).toDouble());
      if (left >= e.bossBarsLeft) continue;
      final sec = bars.number('staggerSec');
      final ticks = math.max(1, (sec / dt).round());
      for (var bar = e.bossBarsLeft; bar > left; bar--) {
        ctx.emit(BossBarBroken(ctx.tick, enemyId: e.id, bar: bar, barsLeft: bar - 1, x: e.x, y: e.y));
      }
      e
        ..bossBarsLeft = left
        ..staggerUntil = ctx.tick + ticks
        ..stunTimer = math.max(e.stunTimer, sec)
        ..vulnerable = math.max(e.vulnerable, bars.number('staggerDamageMul') - 1)
        ..vulnerableTimer = math.max(e.vulnerableTimer, sec);
    }
  }

  /// 매 틱 끝: 게이지 채우기(이번 틱 처치·보스 HP 감소) → 가득이고 (자동 또는 버튼)이면 필살기. 폭주 중엔 쿨타임을 더 깎는다.
  void tickCaptainSkill(GameState s) {
    final c = t.meta.raw.obj('captainSkill');
    final f = field;
    if (f.rushTicks > 0) {
      f.rushTicks--;
      final extra = c.number('attackSpeedMul') - 1;
      for (final g in f.guns) {
        g.cooldown -= dt * stats.attackSpeed * extra; // 공격 속도 × attackSpeedMul(쿨타임을 그만큼 더 깎는다)
      }
    }
    final boss = f.foes.where((e) => e.boss).firstOrNull;
    final ratio = boss == null || !boss.alive ? 0.0 : (boss.hp / boss.maxHp).toDouble();
    final lost = boss != null && f.lastBossRatio > ratio ? f.lastBossRatio - ratio : 0.0;
    f.lastBossRatio = boss == null ? 1 : ratio;
    if (f.rushTicks == 0) {
      f.captainGauge = math.min(1, f.captainGauge + kills * c.number('killGain') + lost * c.number('bossDamageGain'));
    }
    final want = f.ultRequested || s.settings.autoUltimate;
    f.ultRequested = false;
    if (f.captainGauge < 1 || !want || f.rushTicks > 0 || f.captainId == null) return;
    if (!castUltimate(manual: !s.settings.autoUltimate)) return;
    f
      ..captainGauge = 0
      ..rushTicks = math.max(1, (c.number('rushSec') / dt).round());
  }
}
