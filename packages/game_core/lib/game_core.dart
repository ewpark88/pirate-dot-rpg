/// 게임 코어 공개 API: 계약 + 엔진 구현 + 세이브 코덱 + 기본 포트 구현.
library;

export 'contracts.dart';
export 'src/engine/core_engine.dart' show CoreEngine, defaultSystems;
export 'src/ports/xorshift_rng.dart';
export 'src/save/save_codec.dart';
