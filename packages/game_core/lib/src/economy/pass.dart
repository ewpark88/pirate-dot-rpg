import 'package:game_core/src/economy/iap.dart' show entitlementActive;
import 'package:game_core/src/economy/summon.dart' show summonCards;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_iap.dart';
import 'package:game_data/game_data.dart';

// 항해 패스(시즌 30일, docs/specs/economy-iap.md 3절): 경험치 = 일일 퀘스트·출석 받기 + 처음 깬 스테이지,
// 단계마다 무료 줄(누구나)·유료 줄(pass 권리). 무과금도 하루 성실 플레이로 30일에 무료 줄 완주.

/// 지금 시즌의 진행(시즌 id가 바뀌었거나 없으면 새로 — 최고 스테이지는 지금 값부터 센다).
PassState passOf(GameState s, GameTables t) {
  final p = s.pass;
  return p != null && p.season == t.iap.pass.season
      ? p
      : PassState(season: t.iap.pass.season, best: s.progress.bestStage);
}

/// 닿은 단계 수(최대 단계 수까지).
int passLevel(GameState s, GameTables t) {
  final n = passOf(s, t).xp ~/ t.iap.pass.xpPerLevel;
  return n > t.iap.pass.free.length ? t.iap.pass.free.length : n;
}

/// 매 틱: 처음 깬 스테이지만큼 경험치(xp.stage), 시즌이 바뀌었으면 새로.
GameState passTick(GameState s, GameTables t) {
  final p = passOf(s, t);
  final best = s.progress.bestStage;
  if (identical(p, s.pass) && best <= p.best) return s;
  final gain = best > p.best ? (best - p.best) * (t.iap.pass.xp['stage'] ?? 0) : 0;
  return s.copyWith(
    pass: p.copyWith(xp: p.xp + gain, best: best > p.best ? best : p.best),
  );
}

/// 명령 처리 뒤: 퀘스트·출석 보상을 실제로 받았으면(상태가 바뀜) 경험치. [kind]는 pass.xp 키.
GameState passXp(GameState before, GameState after, String kind, GameTables t) {
  if (identical(before, after)) return after;
  final p = passOf(after, t);
  return after.copyWith(pass: p.copyWith(xp: p.xp + (t.iap.pass.xp[kind] ?? 0)));
}

/// 받을 수 있는 다음 단계가 있나([paid]면 유료 줄 — pass 권리 필요).
bool canClaimPass(GameState s, GameTables t, DateTime now, {required bool paid}) {
  final p = passOf(s, t);
  final next = paid ? p.paid : p.free;
  return next < passLevel(s, t) && (!paid || entitlementActive(s, 'pass', now));
}

GameState claimPassReward(GameState s, ClaimPassReward c, SystemContext ctx) {
  final t = ctx.tables;
  if (!canClaimPass(s, t, ctx.clock.now(), paid: c.paid)) return s;
  final p = passOf(s, t);
  final index = c.paid ? p.paid : p.free;
  final r = (c.paid ? t.iap.pass.paid : t.iap.pass.free)[index];
  final title = r.title;
  var next = s.copyWith(
    wallet: s.wallet.copyWith(gems: s.wallet.gems + r.gems, mapPieces: s.wallet.mapPieces + r.pieces),
    pass: c.paid ? p.copyWith(paid: index + 1) : p.copyWith(free: index + 1),
    ship: r.skins.isEmpty ? null : s.ship.copyWith(skinsOwned: {...s.ship.skinsOwned, ...r.skins}),
    progress: title == null || s.progress.titles.contains(title)
        ? null
        : s.progress.copyWith(titles: [...s.progress.titles, title]),
  );
  if (r.summons > 0) next = summonCards(next, ctx, r.summons, reason: c.type);
  if (r.heroCards > 0) {
    next = summonCards(next, ctx, r.heroCards, reason: c.type, guarantee: 'hero', exact: true, maxRarity: 'hero');
  }
  if (r.legendSummon > 0) {
    // 전설 확정 — 첫 전설 유예(meta.firstLegend) 중이면 summonCards가 영웅으로 낮춘다.
    next = summonCards(
      next,
      ctx,
      r.legendSummon,
      reason: c.type,
      guarantee: 'legend',
      exact: true,
      maxRarity: 'legend',
    );
  }
  for (final skin in r.skins.where((k) => !s.ship.skinsOwned.contains(k))) {
    ctx.emit(SkinUnlocked(ctx.tick, id: skin));
  }
  ctx
    ..emit(PassRewardClaimed(ctx.tick, level: index + 1, paid: c.paid, gems: r.gems))
    ..emit(SaveRequested(ctx.tick, reason: c.type));
  return next;
}
