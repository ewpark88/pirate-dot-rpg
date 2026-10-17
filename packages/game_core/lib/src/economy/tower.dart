import 'dart:math' as math;

import 'package:game_core/src/economy/cards.dart' show grantCard;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';

// 심연의 탑 — 경제 (docs/specs/platform-content-v2.md 4절, 요청 platform-tower.md). 도전권 충전·시작·소탕·보상.
// 전투(top_tower.dart)는 tower.active를 보고 장면을 열고, 층을 깨거나 끝날 때 여기 보상 함수를 부른다.

JsonReader towerCfg(GameTables t) => t.meta.raw.obj('tower');

/// 열림: 환생 ≥ unlockRebirths 또는 최고 스테이지 ≥ unlockStage(S2 확정 2026-10-18).
bool towerOpen(GameState s, GameTables t) =>
    s.progress.rebirths >= towerCfg(t).integer('unlockRebirths') ||
    s.progress.bestStage >= towerCfg(t).integer('unlockStage');

/// 매 틱: 열렸는데 상태가 없으면 오늘 도전권 ticketsPerDay로 만든다. 날짜가 바뀐 첫 틱엔 지난 일수 × ticketsPerDay를
/// maxTickets까지 더한다(현상금 티켓과 같은 규칙 — 매일 안 들어와도 쌓인다, 피로 금지).
GameState towerTick(GameState s, SystemContext ctx) {
  final t = ctx.tables;
  final today = localDate(ctx.clock.now());
  final w = s.tower;
  if (w == null) {
    if (!towerOpen(s, t)) return s;
    return s.copyWith(
      tower: TowerState(tickets: towerCfg(t).integer('ticketsPerDay'), refilledOn: today),
    );
  }
  if (w.refilledOn == today) return s;
  final last = w.refilledOn == null ? null : DateTime.tryParse(w.refilledOn!);
  final days = last == null ? 0 : DateTime.parse(today).difference(last).inDays;
  final room = math.max(0, towerCfg(t).integer('maxTickets') - w.tickets);
  final add = math.min(room, math.max(0, days) * towerCfg(t).integer('ticketsPerDay'));
  return s.copyWith(
    tower: w.copyWith(tickets: w.tickets + add, refilledOn: today),
  );
}

/// 지금 탑에 들어갈 수 있나(UI 버튼). 현상금·탑 진행 중이면 안 된다.
bool canStartTower(GameState s, GameTables t) {
  final w = s.tower;
  return towerOpen(s, t) &&
      w != null &&
      w.tickets > 0 &&
      w.active == null &&
      s.bounty?.active == null &&
      s.rush?.active == null &&
      s.dungeon?.active == null;
}

/// StartTower: 도전권 −1, 1층부터. 아니면 그대로(거절).
GameState startTower(GameState s, StartTower c, SystemContext ctx) {
  if (!canStartTower(s, ctx.tables)) return s;
  final w = s.tower!;
  return s.copyWith(
    tower: w.copyWith(tickets: w.tickets - 1, active: const TowerActive(floor: 1)),
  );
}

/// SweepTower: 깬 최고 층 × sweepRatio(최소 1층)의 상자를 바로. 첫 클리어 보상 없음. 도전권 −1.
GameState sweepTower(GameState s, SweepTower c, SystemContext ctx) {
  final w = s.tower;
  if (w == null || w.best < 1 || w.tickets < 1 || w.active != null) return s;
  final floor = towerSweepFloor(w, ctx.tables);
  final chest = towerChest(ctx.tables, floor);
  ctx.emit(TowerSwept(ctx.tick, floor: floor, chestGems: chest.gems, chestCards: chest.cards));
  final paid = grantTowerReward(s, ctx, chest.gems, chest.cards);
  return paid.copyWith(tower: w.copyWith(tickets: w.tickets - 1));
}

/// 소탕 층 = max(1, floor(최고 층 × sweepRatio)) — UI 소탕 버튼도 이 값.
int towerSweepFloor(TowerState w, GameTables t) => math.max(1, (w.best * towerCfg(t).number('sweepRatio')).floor());

/// 도달 층 [floor]의 상자: chest 구간 중 floor 이하로 가장 높은 것(0층이면 없음).
({int gems, int cards}) towerChest(GameTables t, int floor) {
  var out = (gems: 0, cards: 0);
  for (final c in towerCfg(t).objs('chest')) {
    if (c.integer('floor') <= floor) out = (gems: c.integer('gems'), cards: c.intOrNull('cards') ?? 0);
  }
  return out;
}

/// [floor] 층 첫 클리어 보상: firstGems, cardEvery층마다 카드 1.
({int gems, int cards}) towerFirstClear(GameTables t, int floor) {
  final c = towerCfg(t);
  return (gems: c.integer('firstGems'), cards: floor % c.integer('cardEvery') == 0 ? 1 : 0);
}

/// 젬·카드 지급. 카드는 보유 선원 중 하나(결정론 — 엔진 rng)의 기본 등급 카드, 장마다 CardGranted source 'tower'.
GameState grantTowerReward(GameState s, SystemContext ctx, int gems, int cards) {
  var next = gems == 0 ? s : s.copyWith(wallet: s.wallet.copyWith(gems: s.wallet.gems + gems));
  final owned = next.crews.keys.toList()..sort();
  for (var i = 0; i < cards && owned.isNotEmpty; i++) {
    final id = owned[ctx.rng.nextInt(owned.length)];
    next = grantCard(next, ctx, id, ctx.tables.crews.byId(id).baseRarity, 'tower');
  }
  return next;
}

/// 광고 도전권(AdPlacement.towerTicket): +value, 하루 1(dailyLimit) — maxTickets를 넘어도 받는다(현상금과 같음).
GameState towerAdTicket(GameState s, int value, DateTime now) {
  final w = s.tower;
  if (w == null) return s;
  return s.copyWith(
    tower: w.copyWith(tickets: w.tickets + value, adOn: localDate(now)),
  );
}
