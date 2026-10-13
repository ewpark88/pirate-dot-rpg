/// 0단계 계약 (contracts-v1). 레인 사이의 약속이므로 레인 세션은 바꾸지 않는다.
/// 바꾸고 싶으면 docs/contracts/requests/<레인>-<주제>.md에 요청서를 쓰고 임시 어댑터로 계속한다.
///
/// - 상태: `GameState`와 조각들, 전장 스냅샷 `BattleView`
/// - 입력: `Command` (운영자 명령 `OperatorCommand` 포함)
/// - 출력: `GameEvent`, 전투 기록 `RecordedTick` (JSONL)
/// - 엔진: `GameEngine`, 레인 규칙 자리 `GameSystem`
/// - 포트: `Clock` `Rng` `SaveStore` `AdsPort` `AnalyticsPort` `LeaderboardPort` `PurchasePort`
/// - 큰 수: `BigNum`
library;

export 'src/bignum/big_num.dart';
export 'src/bignum/big_num_format.dart';
export 'src/engine/battle_view.dart';
export 'src/engine/commands.dart';
export 'src/engine/events.dart';
export 'src/engine/game_engine.dart';
export 'src/engine/game_state.dart';
export 'src/engine/recording.dart';
export 'src/engine/state_parts.dart';
export 'src/ports/ports.dart';
