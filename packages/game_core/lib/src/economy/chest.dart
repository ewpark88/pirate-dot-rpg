import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/offline.dart';
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// 떠내려오는 보물상자 (설계서 4.6, 스펙 economy-m3-meta 규칙 1). 위치·주기는 ads.json chest.

/// 상자 기본 보상 = 초당 골드 추정(오프라인과 같은 식, 효율 계수 없음) × `chest.baseGoldSec`.
BigNum chestReward(GameState s, GameTables t) =>
    goldPerSecEstimate(s, t, offlineFleet(s, t)).times(t.ads.chest.number('baseGoldSec'));

int _ticks(GameTables t, num sec) => (sec * Duration.millisecondsPerSecond / t.waves.tickMs).round();

/// 매 틱: 떠 있는 상자는 가라앉는 쪽으로, 없으면 주기마다 띄운다(튜토리얼 중 제외).
/// 주기는 엔진 틱 기준 — 첫 상자 `firstOfferAfterSec`, 이후 `intervalSec`마다.
GameState tickChest(GameState state, SystemContext ctx) {
  final b = state.battle;
  if (b == null) return state;
  final c = b.chest;
  if (c != null) {
    final left = c.ticksLeft - 1;
    return state.copyWith(
      battle: left <= 0
          ? b.copyWith(clearChest: true)
          : b.copyWith(
              chest: ChestView(x: c.x, y: c.y, ticksLeft: left),
            ),
    );
  }
  final t = ctx.tables;
  final since = ctx.tick - _ticks(t, t.ads.firstOfferAfterSec);
  if (state.tutorialStep != null || since < 0 || since % _ticks(t, t.ads.chest.number('intervalSec')) != 0) {
    return state;
  }
  return spawnChest(state, ctx);
}

/// 지금 상자를 띄운다 (주기 판정 없음 — 운영자 `OpSpawnChest`도 이것).
GameState spawnChest(GameState state, SystemContext ctx) {
  final t = ctx.tables;
  final ch = t.ads.chest;
  final field = t.waves.raw.obj('field');
  final x =
      field.number('width') * (ch.number('xMin') + ctx.rng.nextDouble() * (ch.number('xMax') - ch.number('xMin')));
  final y = field.obj('laneY').number('surface');
  ctx.emit(ChestSpawned(ctx.tick, x: x, y: y));
  return state.copyWith(
    battle: (state.battle ?? BattleView.empty).copyWith(
      chest: ChestView(x: x, y: y, ticksLeft: _ticks(t, ch.number('floatSec'))),
    ),
  );
}

/// 상자를 열고 [gold]·[gems]를 준다 (탭·광고 공통). 상자가 없으면 상태 그대로.
GameState openChest(GameState state, SystemContext ctx, {BigNum gold = BigNum.zero, int gems = 0}) {
  final b = state.battle;
  if (b?.chest == null) return state;
  ctx
    ..emit(ChestOpened(ctx.tick, gold: gold))
    ..emit(SaveRequested(ctx.tick, reason: 'chest'));
  return state.copyWith(
    wallet: state.wallet.copyWith(gold: state.wallet.gold + gold, gems: state.wallet.gems + gems),
    battle: b!.copyWith(clearChest: true),
  );
}

/// 탭: 기본 보상.
GameState tapChest(GameState state, TapChest command, SystemContext ctx) =>
    openChest(state, ctx, gold: chestReward(state, ctx.tables));
