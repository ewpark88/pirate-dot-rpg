import 'dart:math' as math;

import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/formation.dart';
import 'package:game_core/src/economy/offline.dart';
import 'package:game_core/src/economy/power.dart';
import 'package:game_core/src/economy/rebirth.dart';
import 'package:game_core/src/economy/rebirth_shop.dart';
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

// 환생 버튼 미리보기 (환생 v2 3-2절): '전투력 ×N · 약 M분이면 스테이지 S 돌파'. sim을 돌리지 않는 해석적 추정.

@immutable
class RebirthForecast {
  const RebirthForecast({
    required this.powerMultiplier,
    required this.minutesRaw,
    required this.minutesToBeat,
    required this.targetStage,
  });

  /// 같은 시작 조건(스테이지 1, 상점 시작 레벨)에서 환생 뒤 전투력 ÷ 환생 전 전투력.
  final double powerMultiplier;

  /// 추정 그대로(분). sim 오차 확인용.
  final double minutesRaw;

  /// 표시용: 5분 단위 올림 (UI는 60을 넘으면 '1시간+').
  final int minutesToBeat;

  /// 지금 회차 스테이지 — 이것을 넘는 시간을 추정한다.
  final int targetStage;
}

/// 잠겨 있으면(스테이지 < minStage) null. 버튼 화면에서 부르므로 가볍게(스테이지마다 몇 번의 계산).
RebirthForecast? rebirthForecast(GameState s, GameTables t) {
  final preview = rebirthPreview(s, t);
  if (preview.locked) return null;
  final target = s.progress.stage;
  GameState start(int earned, int rebirths) => s.copyWith(
    progress: s.progress.copyWith(stage: 1, wave: 0, farming: false, mapPiecesEarned: earned, rebirths: rebirths),
    ship: s.ship.copyWith(parts: {for (final id in s.ship.parts.keys) id: startLevel(s, t, id)}),
    wallet: s.wallet.copyWith(gold: BigNum.zero),
  );
  final before = start(s.progress.mapPiecesEarned, s.progress.rebirths);
  final after = start(s.progress.mapPiecesEarned + preview.gain, s.progress.rebirths + 1);
  final pb = fleetPower(before, t).power;
  final ratio = pb.isZero ? 1.0 : (fleetPower(after, t).power / pb).toDouble();
  final minutes = _minutesToBeat(after, t, target);
  final step = t.meta.rebirth.integer('forecastRoundMin');
  return RebirthForecast(
    powerMultiplier: ratio,
    minutesRaw: minutes,
    minutesToBeat: math.max((minutes / step).ceil() * step, step),
    targetStage: target,
  );
}

/// 스테이지 1부터 [target]을 넘을 때까지: 스테이지마다 max(바닥, 체력 ÷ DPS)를 더하고, 번 골드로 가장 싼 강화를 산다.
/// 보스를 제한 시간 안에 못 잡으면 파밍(파 시간만큼 골드를 더 벌어 강화)으로 넘긴다.
double _minutesToBeat(GameState s0, GameTables t, int target) {
  final w = t.waves;
  final fleet = activeFleet(s0, t);
  final mult = upgradeCostMultiplier(s0, t);
  final fast = (s0.progress.bestStage * fastSailFraction(s0, t)).ceil();
  final bossLimit = w.bossTimeLimitSec + bossExtraSec(s0, t);
  final top = w.raw.obj('top');
  final bossWalk = math.max(top.number('bossSpawnRadius') - top.number('bossStandoff'), 0) / w.bossSpeed;
  var levels = {...s0.ship.parts};
  var gold = BigNum.zero;
  var sec = 0.0;
  BigNum dpsNow() => fleetDps(s0.copyWith(ship: s0.ship.copyWith(parts: levels)), t, fleet);
  void spend() {
    while (true) {
      String? best;
      BigNum? cost;
      for (final p in t.shipParts.parts) {
        final lv = levels[p.id] ?? 0;
        if (p.maxLevel != null && lv >= p.maxLevel!) continue;
        final c = partCost(p, lv).times(mult);
        if (cost == null || c < cost) (best, cost) = (p.id, c);
      }
      if (best == null || gold < cost!) return;
      gold = gold - cost;
      levels = {...levels, best: (levels[best] ?? 0) + 1};
    }
  }

  for (var stage = 1; stage <= target; stage++) {
    final goldMul = goldMultiplier(t.shipParts, levels['cargo'] ?? 0) * (1 + rebirthBonus(s0, t));
    final waveGold = stageCurve(w.goldBase, w.goldGrowth, stage).times(w.mobPoolAt(stage) * goldMul);
    final waveHp = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor * w.mobPoolAt(stage));
    final bossHp = stageCurve(
      w.hpBase,
      w.hpGrowth,
      stage,
    ).times(w.bossHpMultiplier * t.regions.bossAt(stage).hpMultiplier);
    final waves = stage <= fast ? w.rebirthSkip.waves : w.wavesPerStage;
    var dps = dpsNow();
    if (dps.isZero) return double.infinity;
    double waveSec() => math.max((waveHp / dps).toDouble(), t.meta.rebirth.number('forecastMinWaveSec')) + w.travelSec;
    sec += waves * waveSec();
    gold = gold + waveGold.times(waves.toDouble());
    spend();
    dps = dpsNow();
    // 보스 벽: 못 잡으면 파를 더 돌며 강화 (상한 — 추정이 끝나지 않는 경우 방지).
    for (
      var farm = 0;
      (bossHp / dps).toDouble() > bossLimit && farm < t.meta.rebirth.integer('forecastFarmWaves');
      farm++
    ) {
      sec += waveSec();
      gold = gold + waveGold;
      spend();
      dps = dpsNow();
    }
    sec += math.max((bossHp / dps).toDouble(), bossWalk);
    gold = gold + stageCurve(w.goldBase, w.goldGrowth, stage).times(w.bossGoldMultiplier * goldMul);
    spend();
  }
  return sec / Duration.secondsPerMinute;
}
