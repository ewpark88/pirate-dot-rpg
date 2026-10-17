import 'package:game_core/src/economy/chest.dart';
import 'package:game_core/src/economy/daily.dart';
import 'package:game_core/src/economy/gold_cap.dart';
import 'package:game_core/src/economy/summon.dart';
import 'package:game_core/src/economy/tower.dart' show towerAdTicket;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

// 보상형 광고와 순풍 (설계서 4.6, 스펙 economy-m3-meta 규칙 2~3). 한도·보상은 ads.json.

AdPlacementDef _def(GameTables t, AdPlacement p) => t.ads.placements.firstWhere((d) => d.id == p.name);

/// 지금 [placement] 광고 보상을 받을 수 있나 (UI 버튼 표시 — 광고 로드 여부는 광고 포트 몫).
/// 하루 총 `dailyCap`, 장치 `dailyLimit`, 장치별 조건(상자가 떠 있음·복귀 보상이 남음).
bool canWatchAd(GameState state, GameTables t, AdPlacement placement) {
  final ads = state.daily.ads;
  final total = ads.values.fold(0, (a, n) => a + n);
  final limit = _def(t, placement).dailyLimit;
  if (total >= t.ads.dailyCap || (limit != null && (ads[placement.name] ?? 0) >= limit)) return false;
  return switch (placement) {
    AdPlacement.chest => state.battle?.chest != null,
    AdPlacement.offline => state.lastOfflineGold != null,
    AdPlacement.bountyTicket => state.bounty != null,
    AdPlacement.towerTicket => state.tower != null,
    _ => true,
  };
}

/// 광고 보상 지급. 받을 수 없으면 상태 그대로.
GameState grantAdReward(GameState state, GrantAdReward command, SystemContext ctx) {
  final t = ctx.tables;
  if (!canWatchAd(state, t, command.placement)) return state;
  final reward = _def(t, command.placement).reward;
  final s = countAd(state, t, command.placement.name);
  final now = ctx.clock.now();
  return switch (command.placement) {
    AdPlacement.chest =>
      command.choice == 'gems'
          ? openChest(s, ctx, gems: reward.integer('altGems'))
          : openChest(s, ctx, gold: chestReward(s, t).times(reward.number('value'))),
    AdPlacement.tailwind => _saved(addTailwind(s, t, now, Duration(seconds: reward.integer('durationSec'))), ctx),
    AdPlacement.offline => _saved(
      // 광고 ×2도 복귀 보상과 같은 한도(화물칸 × offline.capMultiplier)
      grantGold(s.copyWith(clearLastOfflineGold: true), ctx, s.lastOfflineGold!, capScale: offlineCapScale(ctx.tables)),
      ctx,
    ),
    AdPlacement.freeSummon => summonCards(s, ctx, reward.integer('value'), reason: command.type),
    // 현상금 입장권 +1 (하루 1 = dailyLimit, 상한 ticketCap을 넘어도 받는다 — 기획 1절).
    // 자동 강화 10분(사용자 결정 — 평소엔 수동, 자동은 광고 보상으로만). 겹쳐 보면 maxStackSec까지 늘어난다.
    AdPlacement.autoUpgrade => _saved(addAutoUpgrade(s, t, now), ctx),
    AdPlacement.bountyTicket => _saved(
      s.copyWith(
        bounty: s.bounty!.copyWith(tickets: s.bounty!.tickets + reward.integer('value'), adOn: localDate(now)),
      ),
      ctx,
    ),
    AdPlacement.towerTicket => _saved(towerAdTicket(s, reward.integer('value'), now), ctx), // 탑 도전권 +1(하루 1)
    // 함포 지원: 경제가 종료 시각을 채우고, 피해 보너스는 전투가 Buffs.bossSupportUntil을 읽어 적용한다.
    AdPlacement.bossSupport => _saved(
      s.copyWith(
        buffs: s.buffs.copyWith(bossSupportUntil: now.add(Duration(seconds: reward.integer('durationSec'))).toUtc()),
      ),
      ctx,
    ),
  };
}

GameState _saved(GameState s, SystemContext ctx) {
  ctx.emit(SaveRequested(ctx.tick, reason: 'adReward'));
  return s;
}

/// 순풍 남은 시간. 끝났으면 zero.
Duration tailwindRemaining(GameState state, DateTime now) {
  final until = state.buffs.tailwindUntil;
  if (until == null || !until.isAfter(now)) return Duration.zero;
  return until.difference(now);
}

/// 순풍 [d]를 더한다. 남은 시간은 `tailwind.maxStackSec`을 넘지 않는다.
GameState addTailwind(GameState state, GameTables t, DateTime now, Duration d) {
  final max = Duration(seconds: _def(t, AdPlacement.tailwind).reward.integer('maxStackSec'));
  var left = tailwindRemaining(state, now) + d;
  if (left > max) left = max;
  return state.copyWith(buffs: state.buffs.copyWith(tailwindUntil: now.add(left).toUtc()));
}

GameState opGrantTailwind(GameState state, OpGrantTailwind c, SystemContext ctx) =>
    addTailwind(state, ctx.tables, ctx.clock.now(), c.duration);

/// 자동 강화 버프 남은 시간 (없거나 끝났으면 0).
Duration autoUpgradeRemaining(GameState s, DateTime now) {
  final until = s.buffs.autoUpgradeUntil;
  return until == null || !until.isAfter(now) ? Duration.zero : until.difference(now);
}

GameState addAutoUpgrade(GameState state, GameTables t, DateTime now) {
  final r = _def(t, AdPlacement.autoUpgrade).reward;
  var left = autoUpgradeRemaining(state, now) + Duration(seconds: r.integer('durationSec'));
  final max = Duration(seconds: r.integer('maxStackSec'));
  if (left > max) left = max;
  return state.copyWith(buffs: state.buffs.copyWith(autoUpgradeUntil: now.add(left).toUtc()));
}
