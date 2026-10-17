import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';

// 도감 수집 보상 (S1 2026-10-17 '수집의 재미', 경제 S2 collectionRewards) 글 도우미 — 화면은 CrewHeader(머리 한 줄).

/// 보상 한 칸의 글 ('젬 30' · '무료 소환 1회' · 둘 다면 ' + ').
String collectRewardText(AppLocalizations l, CollectionRewardView r) => [
  if (r.gems > 0) l.uiCollectGems(r.gems),
  if (r.summons > 0) l.uiCollectSummons(r.summons),
].join(' + ');

/// 다음에 닿을(아직 못 닿은) 칸. 다 닿았으면 null.
CollectionRewardView? nextCollectReward(GameState s, GameTables t) =>
    collectionRewards(s, t).where((r) => !r.reached).firstOrNull;
