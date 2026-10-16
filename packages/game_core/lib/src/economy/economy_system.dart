import 'package:game_core/src/economy/ads.dart';
import 'package:game_core/src/economy/auto_upgrade.dart' show autoUpgradeStep;
import 'package:game_core/src/economy/bounty_flow.dart';
import 'package:game_core/src/economy/chest.dart';
import 'package:game_core/src/economy/daily.dart';
import 'package:game_core/src/economy/formation.dart';
import 'package:game_core/src/economy/merge.dart';
import 'package:game_core/src/economy/offline.dart';
import 'package:game_core/src/economy/operator.dart';
import 'package:game_core/src/economy/rebirth.dart';
import 'package:game_core/src/economy/rebirth_shop.dart';
import 'package:game_core/src/economy/sea_events.dart' show pickBottle;
import 'package:game_core/src/economy/summon.dart';
import 'package:game_core/src/economy/tutorial.dart';
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
    final Summon c => summon(state, c, ctx),
    final MergeAllCards c => tutorialAfterMerge(mergeAllCards(state, c, ctx), ctx.tables),
    final PromoteCrew c => promoteCrew(state, c, ctx),
    final SetFleetSlot c => setFleetSlot(state, c, ctx),
    final AutoFleet c => onAutoFleet(state, c, ctx),
    final ClaimOffline c => claimOffline(state, c, ctx),
    final ClaimDaily c => claimDaily(state, c, ctx),
    final ClaimAttendance c => claimAttendance(state, c, ctx),
    final OpSetCrew c => opSetCrew(state, c, ctx),
    final OpGrant c => opGrant(state, c, ctx),
    final OpSetShip c => opSetShip(state, c, ctx),
    final OpAdvanceClock c => opAdvanceClock(state, c, ctx),
    final TapChest c => tapChest(state, c, ctx),
    final GrantAdReward c => grantAdReward(state, c, ctx),
    OpSpawnChest() => spawnChest(state, ctx),
    final OpGrantTailwind c => opGrantTailwind(state, c, ctx),
    final TutorialAck c => tutorialAck(state, ctx.tables, c),
    SkipTutorial() => state.copyWith(clearTutorial: true),
    final OpSetTutorial c => opSetTutorial(state, c),
    final Rebirth c => onRebirth(state, c, ctx),
    final OpRebirthNow c => opRebirthNow(state, c, ctx),
    final OpReset c => opReset(state, c, ctx),
    final BuyRebirthUpgrade c => buyRebirthUpgrade(state, c, ctx),
    final SelectShipSkin c => selectShipSkin(state, c),
    final SelectTitle c => selectTitle(state, c),
    final SetTreasureRoute c => setTreasureRoute(state, c, ctx),
    final OpGrantPieces c => opGrantPieces(state, c),
    final OpSetRebirths c => opSetRebirths(state, c),
    final PickBottle c => pickBottle(state, c, ctx),
    CancelAutoUpgrade() => state.copyWith(buffs: state.buffs.copyWith(clearAutoUpgrade: true)),
    MarkHint(:final id) =>
      state.settings.hints.contains(id) ? null : state.copyWith(settings: state.settings.withHint(id)),
    final StartBounty c => startBounty(state, c, ctx),
    final SweepBounty c => sweepBounty(state, c, ctx),
    final OpSetBountyTickets c => opSetBountyTickets(state, c),
    final OpSetWeekday c => opSetWeekday(state, c),
    _ => null,
  };

  @override
  GameState update(GameState state, SystemContext ctx) => autoUpgradeStep(
    tickChest(
      bountyTick(
        tutorialTick(
          rollDay(ensureRebirthRewards(ensureFleet(state, ctx.tables), ctx.tables), ctx.clock.now()),
          ctx.tables,
        ),
        ctx,
      ),
      ctx,
    ),
    ctx,
  );
}
