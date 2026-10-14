import 'dart:math' as math;

import 'package:game_core/src/battle/fleet.dart' show autoFleet;
import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/cards.dart';
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/economy/rebirth.dart';
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

// 오프라인 보상과 초당 골드 추정 (설계서 4.7). 전투를 돌리지 않고 식으로 계산한다. sim도 쓴다.

/// 원정대 단일 대상 DPS 추정. 곱셈 항은 전투와 같다(설계서 4.8):
/// 대포 × 선원 파워 × 배 등급 × 계열 power × 치명타 기대값 × 공격 속도 ÷ 발사 간격. 범위 이득은 빼서 보수적으로.
BigNum fleetDps(GameState s, GameTables t, List<String> fleet) {
  final ship = ShipStats.of(t.shipParts, s.ship);
  final tier = 1 + t.shipTiers.tierAt(s.progress.stage).damageBonus;
  final crit = 1 + ship.critChance * (ship.critMultiplier - 1);
  var perAttack = 0.0;
  for (final id in fleet) {
    final crew = s.crews[id];
    if (crew == null) continue;
    final a = t.skills.byId(t.crews.byId(id).family).attack;
    perAttack += crewPowerMultiplier(t.growth, t.rarities, crew.level) * a.power / a.intervalSec;
  }
  return ship.attack.times(perAttack * tier * crit * ship.attackSpeed * (1 + rebirthBonus(s, t)));
}

/// 초당 골드 추정 = 한 파 골드 / (max(한 파 HP ÷ DPS, offline.minWaveSec) + 이동 시간). 보스는 넘지 않는다.
BigNum goldPerSecEstimate(GameState s, GameTables t, List<String> fleet) {
  final dps = fleetDps(s, t, fleet);
  if (dps <= BigNum.zero) return BigNum.zero;
  final w = t.waves;
  final stage = s.progress.stage;
  final n = w.mobCountAt(stage);
  final waveGold = stageCurve(
    w.goldBase,
    w.goldGrowth,
    stage,
  ).times(n * goldMultiplier(t.shipParts, s.ship.level('cargo')) * (1 + rebirthBonus(s, t)));
  final waveHp = stageCurve(w.hpBase, w.hpGrowth, stage).times(n * w.waveHpPoolFactor);
  final waveSec = math.max((waveHp / dps).toDouble(), t.meta.offlineMinWaveSec);
  return waveGold / BigNum.from(waveSec + w.travelSec);
}

/// 오프라인 동안의 출전 선원 = 지금 배 등급 슬롯으로 자동 편성.
List<String> offlineFleet(GameState s, GameTables t) => autoFleet(s, t, t.shipTiers.tierAt(s.progress.stage).slots);

/// 복귀 보상 미리보기 (UI 복귀 팝업). [ClaimOffline]과 같은 계산이고 난수를 쓰지 않는다.
/// 경과 = `now − savedAt`을 `offline.maxSec`로 자른다. `offline.minSec` 미만(시계 역행 포함)이면 null.
/// 골드는 × `offline.efficiency`, 카드는 `cardsPerMax × 경과 / maxSec`장(내림, 출전이 없으면 0).
@immutable
class OfflinePreview {
  const OfflinePreview({required this.seconds, required this.gold, required this.cards});

  final int seconds;
  final BigNum gold;
  final int cards;
}

OfflinePreview? offlinePreview(GameState s, GameTables t, DateTime now) {
  final elapsed = now.difference(s.savedAt).inSeconds;
  if (elapsed < t.meta.offlineMinSec) return null;
  final seconds = math.min(elapsed, t.meta.offlineMaxSec);
  final fleet = offlineFleet(s, t);
  return OfflinePreview(
    seconds: seconds,
    gold: goldPerSecEstimate(s, t, fleet).times(seconds * t.meta.offlineEfficiency),
    cards: fleet.isEmpty ? 0 : t.meta.offlineCardsPerMax * seconds ~/ t.meta.offlineMaxSec,
  );
}

/// 복귀 보상 받기 = [offlinePreview]를 지급하고 카드는 출전 선원에게 보스 드롭 확률로 나눈다.
/// 받고 나면 savedAt = now (두 번 받기 방지). 받을 것이 없으면 상태 그대로, 이벤트 없음.
GameState claimOffline(GameState state, ClaimOffline command, SystemContext ctx) {
  final t = ctx.tables;
  final now = ctx.clock.now();
  final p = offlinePreview(state, t, now);
  if (p == null) return state;

  final fleet = offlineFleet(state, t);
  var s = state.copyWith(
    savedAt: now,
    wallet: state.wallet.copyWith(gold: state.wallet.gold + p.gold),
    lastOfflineGold: p.gold,
  );
  for (var i = 0; i < p.cards; i++) {
    s = receiveCard(s, t, fleet[ctx.rng.nextInt(fleet.length)], rollRarity(t.rarities.bossDropRates, ctx.rng));
  }
  ctx
    ..emit(OfflineReward(ctx.tick, gold: p.gold, cards: p.cards, seconds: p.seconds))
    ..emit(SaveRequested(ctx.tick, reason: command.type));
  return s;
}
