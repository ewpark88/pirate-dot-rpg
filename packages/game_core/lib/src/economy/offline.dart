import 'dart:math' as math;

import 'package:game_core/src/battle/fleet.dart' show autoFleet;
import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/cards.dart';
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

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
  return ship.attack.times(perAttack * tier * crit * ship.attackSpeed);
}

/// 초당 골드 추정 = 한 파 골드 / (한 파 HP ÷ DPS + 이동 시간). 보스는 넘지 않는다.
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
  ).times(n * goldMultiplier(t.shipParts, s.ship.level('cargo')));
  final waveHp = stageCurve(w.hpBase, w.hpGrowth, stage).times(n * w.waveHpPoolFactor);
  return waveGold / BigNum.from((waveHp / dps).toDouble() + w.travelSec);
}

/// 오프라인 동안의 출전 선원 = 지금 배 등급 슬롯으로 자동 편성.
List<String> offlineFleet(GameState s, GameTables t) => autoFleet(s, t, t.shipTiers.tierAt(s.progress.stage).slots);

/// 복귀 보상 받기. 경과 = `now − savedAt`을 0~`offline.maxSec`로 자른다(시계 역행 0).
/// 카드는 `cardsPerMax × 경과 / maxSec`장(내림), 출전 선원에게 보스 드롭 확률로.
/// 받고 나면 savedAt = now (두 번 받기 방지). 받을 것이 없으면 상태 그대로, 이벤트 없음.
GameState claimOffline(GameState state, ClaimOffline command, SystemContext ctx) {
  final t = ctx.tables;
  final now = ctx.clock.now();
  final seconds = math.min(math.max(now.difference(state.savedAt).inSeconds, 0), t.meta.offlineMaxSec);
  if (seconds <= 0) return state;

  final fleet = offlineFleet(state, t);
  final gold = goldPerSecEstimate(state, t, fleet).times(seconds);
  final cards = fleet.isEmpty ? 0 : t.meta.offlineCardsPerMax * seconds ~/ t.meta.offlineMaxSec;
  var s = state.copyWith(
    savedAt: now,
    wallet: state.wallet.copyWith(gold: state.wallet.gold + gold),
  );
  for (var i = 0; i < cards; i++) {
    s = receiveCard(s, t, fleet[ctx.rng.nextInt(fleet.length)], rollRarity(t.rarities.bossDropRates, ctx.rng));
  }
  ctx
    ..emit(OfflineReward(ctx.tick, gold: gold, cards: cards, seconds: seconds))
    ..emit(SaveRequested(ctx.tick, reason: command.type));
  return s;
}
