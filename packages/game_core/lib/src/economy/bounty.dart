import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/cards.dart' show grantCard;
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

// 현상금 사냥 경제 (docs/specs/platform-content-bounty.md, 요청 platform-bounty-b0b2.md).
// 표는 meta.bounty(기획의 bounty.json 내용 — 새 표 파일은 공유 game_tables.dart를 고쳐야 해서 meta 안에 둔다).
// B0: 엔진(B1)·UI(B4)가 부를 함수. 티켓 충전·소탕·광고 티켓·명령 처리는 B2.

JsonReader _cfg(GameTables t) => t.meta.raw.obj('bounty');

/// 일요일: 아무 보스.
const anyBoss = '*';

/// 요일(1 월 ~ 7 일)의 보스 id. 일요일은 [anyBoss].
String bountyBossOn(GameTables t, int weekday) =>
    _cfg(t).objs('days').firstWhere((d) => d.integer('weekday') == weekday).str('boss');

/// 현상금 보스 목록 (월~토 순서).
List<String> bountyBosses(GameTables t) => [
  for (final d in _cfg(t).objs('days'))
    if (d.str('boss') != anyBoss) d.str('boss'),
];

/// 단계 [tier]의 보스 HP = 스테이지 tier × stagePerTier의 해역 보스 HP × 보스 배율 × hpMultiplier.
BigNum bountyBossHp(GameTables t, String bossId, int tier) {
  final w = t.waves;
  final c = _cfg(t);
  final boss = t.regions.bosses[bossId];
  return stageCurve(
    w.hpBase,
    w.hpGrowth,
    tier * c.integer('stagePerTier'),
  ).times(w.bossHpMultiplier * (boss?.hpMultiplier ?? 1) * c.number('hpMultiplier'));
}

/// 이 보스로 지금 도전할 수 있는가: 오늘 보스(일요일은 아무), 1 ≤ tier ≤ min(깬 단계 + 1, maxTier), 티켓 ≥ 1, 진행 중 아님.
/// [weekday]: 운영자가 고정한 요일(1~7). 없으면 [now]의 현지 요일.
bool canStartBounty(GameState s, GameTables t, DateTime now, String bossId, int tier, {int? weekday}) {
  final b = s.bounty;
  if (b == null || b.tickets < 1 || b.active != null) return false;
  if (s.tower?.active != null || s.rush?.active != null || s.dungeon?.active != null) return false; // 다른 장면 중엔 안 됨
  if (!bountyBosses(t).contains(bossId)) return false;
  final today = bountyBossOn(t, weekday ?? now.weekday);
  if (today != anyBoss && today != bossId) return false;
  final open = (b.cleared[bossId] ?? 0) + 1;
  return tier >= 1 && tier <= open && tier <= _cfg(t).integer('maxTier');
}

/// 단계 [tier] 보상: floor(base + perTier × (tier − 1)). 보상 종류는 그 보스의 요일 것.
/// cards면 보유 선원 중 하나를 [rng]로 고른다(결정론). gifts는 crew-bond 전까지 giftGems배 젬.
BountyReward bountyReward(GameState s, GameTables t, String bossId, int tier, Rng rng) {
  final day = _cfg(t).objs('days').firstWhere((d) => d.str('boss') == bossId);
  final r = day.obj('reward');
  final amount = (r.number('base') + r.number('perTier') * (tier - 1)).floor();
  switch (r.str('type')) {
    case 'cards':
      final owned = s.crews.keys.toList()..sort();
      if (owned.isEmpty) return const BountyReward(type: 'cards', amount: 0);
      return BountyReward(type: 'cards', amount: amount, crewId: owned[rng.nextInt(owned.length)]);
    case 'gifts':
      return BountyReward(type: 'gems', amount: amount * _cfg(t).integer('giftGems'));
    default:
      return BountyReward(type: r.str('type'), amount: amount);
  }
}

/// 보상 지급. 지도 조각은 쓸 조각·모은 조각(환생 누계) 둘 다. 카드는 그 선원의 기본 등급 카드 amount장(장마다 CardGranted source 'bounty').
GameState grantBountyReward(GameState s, SystemContext ctx, BountyReward r) {
  final t = ctx.tables;
  switch (r.type) {
    case 'gems':
      return s.copyWith(wallet: s.wallet.copyWith(gems: s.wallet.gems + r.amount));
    case 'mapPieces':
      return s.copyWith(
        wallet: s.wallet.copyWith(mapPieces: s.wallet.mapPieces + r.amount),
        progress: s.progress.copyWith(mapPiecesEarned: s.progress.mapPiecesEarned + r.amount),
      );
    case 'cards' when r.crewId != null:
      var next = s;
      final rarity = t.crews.byId(r.crewId!).baseRarity;
      for (var i = 0; i < r.amount; i++) {
        next = grantCard(next, ctx, r.crewId!, rarity, 'bounty');
      }
      return next;
  }
  return s;
}
