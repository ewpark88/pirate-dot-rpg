/// 게임 코어 공개 API: 계약 + 엔진 구현 + 세이브 코덱 + 기본 포트 구현.
library;

export 'contracts.dart';
export 'src/battle/fleet.dart' show autoFleet;
export 'src/battle/gun.dart' show Gun; // UI 상세가 선원 실제 공격(aim·등급 덮어쓰기)을 읽게(S4)
export 'src/economy/ads.dart' show canWatchAd, tailwindRemaining;
export 'src/economy/cards.dart';
export 'src/economy/chest.dart' show chestReward;
export 'src/economy/crew_stats.dart';
export 'src/economy/daily.dart'
    show AttendanceView, QuestView, addQuestProgress, attendance, canClaimDaily, dailyQuests;
export 'src/economy/formation.dart' show activeFleet, emptySlotCount, fleetSlots;
export 'src/economy/meta_views.dart' show CollectionBonus, GoalKind, NextGoal, collectionBonus, nextGoal;
export 'src/economy/offline.dart';
export 'src/economy/rebirth.dart' show RebirthPreview, piecesFor, rebirthBonus, rebirthPreview;
export 'src/economy/ship_stats.dart';
export 'src/engine/core_engine.dart' show CoreEngine, defaultSystems;
export 'src/ports/xorshift_rng.dart';
export 'src/save/save_codec.dart';
