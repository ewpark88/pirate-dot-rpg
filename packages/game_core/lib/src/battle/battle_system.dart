import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';

/// 전투 레인(S1)이 채운다: 무리 생성·이동, 자동 발사·스킬·궁극기, 피해 계산,
/// 동시 처치, 보스 타이머, 파밍 전환, 히트스톱 이벤트 (docs/lanes/battle.md).
///
/// 수치는 SystemContext.tables에서만 읽는다(숫자 리터럴은 check가 막는다).
class BattleSystem implements GameSystem {
  const BattleSystem();

  @override
  GameState? handle(GameState state, Command command, SystemContext ctx) => switch (command) {
    // TODO(battle): ChallengeBoss, TriggerUltimate, OpSpawnBoss, OpJumpStage, OpSetWave, OpCastSkill …
    _ => null,
  };

  @override
  GameState update(GameState state, SystemContext ctx) => state;
}
