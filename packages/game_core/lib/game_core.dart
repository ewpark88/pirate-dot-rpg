/// 게임 코어 공개 API: 계약 + 엔진 구현 + 세이브 코덱 + 기본 포트 구현.
library;

export 'contracts.dart';
export 'src/economy/cards.dart';
export 'src/economy/crew_stats.dart';
export 'src/economy/offline.dart';
export 'src/economy/ship_stats.dart';
export 'src/engine/core_engine.dart' show CoreEngine, defaultSystems;
export 'src/ports/xorshift_rng.dart';
export 'src/save/save_codec.dart';
