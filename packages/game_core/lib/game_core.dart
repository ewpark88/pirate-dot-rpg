/// 게임 코어 공개 API: 계약 + 엔진 구현 + 세이브 코덱 + 기본 포트 구현.
library;

export 'contracts.dart';
export 'src/economy/ads.dart' show canWatchAd, tailwindRemaining;
export 'src/economy/cards.dart';
export 'src/economy/chest.dart' show chestReward;
export 'src/economy/crew_stats.dart';
// QuestView·AttendanceView 타입은 ui 레인 임시 타입과 이름이 겹쳐, ui가 실제 함수로 바꾼 뒤 export한다.
export 'src/economy/daily.dart' show addQuestProgress, attendance, canClaimDaily, dailyQuests;
// NextGoal·GoalKind·CollectionBonus 타입도 ui 임시 타입과 겹쳐 함수만.
export 'src/economy/meta_views.dart' show collectionBonus, nextGoal;
export 'src/economy/offline.dart';
export 'src/economy/ship_stats.dart';
export 'src/engine/core_engine.dart' show CoreEngine, defaultSystems;
export 'src/ports/xorshift_rng.dart';
export 'src/save/save_codec.dart';
