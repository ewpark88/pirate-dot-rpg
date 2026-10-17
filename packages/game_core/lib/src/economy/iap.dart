import 'package:game_core/src/economy/summon.dart' show summonCards;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_iap.dart';
import 'package:game_data/game_data.dart';

// 유료 상품 지급·권리 (계약 platform-iap, 기획 docs/specs/economy-iap.md — 사용자 가격 확정 2026-10-17).
// 원칙: 무과금도 같은 끝, 과금은 시간 단축·편의·꾸밈. 광고 제거는 '보상형 광고를 안 보고 바로 보상'(하루 한도 그대로 — 앱이 noAds면 광고를 건너뛰고 GrantAdReward).

/// 권리 [id]가 [now]에 켜져 있나.
bool entitlementActive(GameState s, String id, DateTime now) => s.entitlements[id]?.activeAt(now) ?? false;

/// 산 기록 키(첫 구매 2배·계정당 한도).
String _bought(String productId) => 'product:$productId';

GameState grantPurchase(GameState s, GrantPurchase c, SystemContext ctx) {
  final t = ctx.tables;
  final p = t.iap.products[c.productId];
  if (p == null || s.purchaseTokens.contains(c.token)) return s;
  final record = s.entitlements[_bought(p.id)];
  final limit = p.limit;
  if (limit != null && (record?.count ?? 0) >= limit) return s;
  final at = c.at.toUtc();
  final gems = p.firstBuyDouble && record == null ? p.gems * t.iap.firstBuyMultiplier : p.gems;
  final rights = <String, Entitlement>{...s.entitlements};
  for (final r in p.entitlements) {
    final had = rights[r.id];
    final days = r.days;
    if (days == null) {
      rights[r.id] = Entitlement(since: had?.since ?? at); // 영구(구독 기록이 있어도 영구가 이긴다)
    } else if (had == null || had.until != null) {
      final from = had?.until != null && had!.until!.isAfter(at) ? had.until! : at; // 남은 기간에 이어 붙인다
      rights[r.id] = Entitlement(
        since: had?.since ?? at,
        until: from.add(Duration(days: days)),
        claimedOn: had?.claimedOn,
      );
    }
  }
  rights[_bought(p.id)] = record == null ? Entitlement(since: at) : record.copyWith(count: record.count + 1);
  final tokens = [...s.purchaseTokens, c.token];
  var next = s.copyWith(
    wallet: s.wallet.copyWith(gems: s.wallet.gems + gems),
    entitlements: rights,
    purchaseTokens: tokens.length > purchaseTokenKeep ? tokens.sublist(tokens.length - purchaseTokenKeep) : tokens,
    ship: p.skins.isEmpty ? null : s.ship.copyWith(skinsOwned: {...s.ship.skinsOwned, ...p.skins}),
  );
  if (p.summons > 0) next = summonCards(next, ctx, p.summons, reason: c.type);
  if (p.heroCards > 0) {
    next = summonCards(
      next,
      ctx,
      p.heroCards,
      reason: c.type,
      guarantee: 'hero',
      exact: p.heroCards == 1,
      maxRarity: 'hero',
    );
  }
  for (final skin in p.skins.where((k) => !s.ship.skinsOwned.contains(k))) {
    ctx.emit(SkinUnlocked(ctx.tick, id: skin));
  }
  for (final r in p.entitlements) {
    ctx.emit(EntitlementChanged(ctx.tick, id: r.id, active: true));
  }
  ctx
    ..emit(
      PurchaseGranted(
        ctx.tick,
        productId: p.id,
        gems: gems,
        summons: p.summons,
        heroCards: p.heroCards,
        skins: p.skins,
        rights: [for (final r in p.entitlements) r.id],
      ),
    )
    ..emit(SaveRequested(ctx.tick, reason: c.type)); // 저장이 끝난 뒤에만 앱이 complete(token)
  return next;
}

GameState revokeEntitlement(GameState s, String id, SystemContext ctx) {
  if (!s.entitlements.containsKey(id)) return s;
  ctx
    ..emit(EntitlementChanged(ctx.tick, id: id, active: false))
    ..emit(SaveRequested(ctx.tick, reason: 'revokeEntitlement'));
  return s.copyWith(entitlements: {...s.entitlements}..remove(id));
}

GameState opSetEntitlement(GameState s, OpSetEntitlement c, SystemContext ctx) {
  if (!c.on) return revokeEntitlement(s, c.id, ctx);
  ctx.emit(EntitlementChanged(ctx.tick, id: c.id, active: true));
  return s.copyWith(
    entitlements: {
      ...s.entitlements,
      c.id: Entitlement(since: ctx.clock.now().toUtc()),
    },
  );
}

/// 월간 젬: 구독 중이고 오늘 아직 안 받았으면 iap.gemSubDaily젬.
bool canClaimGemSub(GameState s, DateTime now) =>
    entitlementActive(s, 'gemSub', now) && s.entitlements['gemSub']!.claimedOn != localDate(now);

GameState claimGemSub(GameState s, SystemContext ctx) {
  final now = ctx.clock.now();
  if (!canClaimGemSub(s, now)) return s;
  final gems = ctx.tables.iap.gemSubDaily;
  ctx.emit(SaveRequested(ctx.tick, reason: 'claimGemSub'));
  return s.copyWith(
    wallet: s.wallet.copyWith(gems: s.wallet.gems + gems),
    entitlements: {
      ...s.entitlements,
      'gemSub': s.entitlements['gemSub']!.copyWith(claimedOn: localDate(now)),
    },
  );
}

/// 2배속 권리가 켜져 있으면 배속(iap.speedMultiplier), 아니면 null.
int? purchasedSpeed(GameState s, GameTables t, DateTime now) =>
    entitlementActive(s, 'speed', now) ? t.iap.speedMultiplier : null;
