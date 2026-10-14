import 'package:game_core/src/economy/upgrade.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';

/// 경제·성장 레인(S2)이 채운다: 배 강화, 소환·천장, 카드 합치기·승급, 증표,
/// 광고 보상, 환생, 일일 퀘스트·출석, 오프라인 보상 (docs/lanes/economy.md).
///
/// 수치는 SystemContext.tables에서만 읽는다(숫자 리터럴은 check가 막는다).
class EconomySystem implements GameSystem {
  const EconomySystem();

  @override
  GameState? handle(GameState state, Command command, SystemContext ctx) => switch (command) {
    final UpgradePart c => upgradePart(state, c, ctx),
    // TODO(economy): Summon, MergeAllCards, PromoteCrew, GrantAdReward, Rebirth …
    _ => null,
  };

  @override
  GameState update(GameState state, SystemContext ctx) => state;
}
