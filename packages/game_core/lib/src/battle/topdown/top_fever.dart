import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/economy/fever.dart' show feverOn;
import 'package:game_core/src/engine/game_state.dart';

/// 피버 오라 (사용자 지시 '피버 동안 배가 빠르게 나아가며 주변 적을 녹인다', 표 meta.fever.aura — S2).
/// 피버 중 배 중심에서 반경 = 배 반경 × radiusShipMul 안의 적에게 pulseSec마다 피해:
/// 한 펄스 = 그 스테이지 잡몹 한 마리 HP × (pulseSec ÷ waveHpPerSec) — waveHpPerSec초면 닿은 잡몹이 녹는다. 보스는 × bossFactor.
/// 표에 aura가 없으면 아무것도 하지 않는다. 처치·골드·숫자는 보통 공격과 같은 길(strike, 선원 없음).
extension FeverAura on Round {
  void feverAura(GameState s) {
    final fever = t.meta.raw.obj('fever');
    final g = geo;
    if (!fever.has('aura') || !feverOn(s) || g is! TopGeometry) return;
    final a = fever.obj('aura');
    final pulse = math.max(1, (a.numberOr('pulseSec', dt) / dt).round());
    if (ctx.tick % pulse != 0) return;
    final radius = g.top.shipRadius * a.number('radiusShipMul');
    final stage = field.stage;
    final share = w.mobPoolAt(stage) / w.topMobCountAt(stage);
    final mobHp = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor * share);
    final perPulse = mobHp.times(pulse * dt / a.number('waveHpPerSec'));
    final bossFactor = a.numberOr('bossFactor', 1);
    final hits = [
      for (final e in field.living)
        if (e.holdSec <= 0 && _within(g, e, radius)) (foe: e, factor: e.boss ? bossFactor : 1.0),
    ];
    if (hits.isEmpty) return;
    strike((x: g.top.shipX, y: g.top.shipY, hits: hits), perPulse);
  }

  static bool _within(TopGeometry g, Foe e, double radius) {
    final dx = e.x - g.top.shipX;
    final dy = e.y - g.top.shipY;
    final r = radius + g.top.radiusOf(e);
    return dx * dx + dy * dy <= r * r;
  }
}

/// 피버 중 '배가 전진하는 느낌': 배 앞쪽(위)에서 오는 적이 더 빨리 다가온다 — meta.fever.aura.forwardBoost(없으면 0).
double feverForwardBoost(GameState s, Map<String, Object?> feverRaw) {
  final aura = feverRaw['aura'];
  if (aura is! Map || !feverOn(s)) return 0;
  return (aura['forwardBoost'] as num?)?.toDouble() ?? 0;
}
