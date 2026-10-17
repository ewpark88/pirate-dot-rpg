import 'dart:math' as math;

import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/rebirth_shop.dart';
import 'package:game_core/src/economy/ship_stats.dart' show partLook;
import 'package:game_core/src/economy/summon.dart' show summonCards;
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

// 환생: 보물지도 (설계서 4.5, 스펙 economy-rebirth). 수치는 meta.rebirth.

/// 스테이지 [stage]에서 환생하면 얻는 조각 `floor((stage − offset)^exponent)`. offset 이하면 0.
int piecesFor(GameTables t, int stage) {
  final r = t.meta.rebirth;
  final over = stage - r.integer('offset');
  return over <= 0 ? 0 : math.pow(over, r.number('exponent')).floor();
}

/// 전체 피해·골드 % 보너스 = 모은 조각 누계 × `bonusPerPiece` (환생 v2: 쓴 조각과 무관 — 상점 구매가 순수한 이득) (설계서 4.8 마지막 합에 더한다).
double rebirthBonus(GameState s, GameTables t) => s.progress.mapPiecesEarned * t.meta.rebirth.number('bonusPerPiece');

/// 환생 버튼 미리보기 (UI 요청). [rebirth]와 같은 계산.
@immutable
class RebirthPreview {
  const RebirthPreview({
    required this.locked,
    required this.minStage,
    required this.currentPieces,
    required this.gain,
    required this.nextPieceInStages,
    required this.bonusPerPiece,
    this.earned = 0,
  });

  /// 해금 전(스테이지 < minStage).
  final bool locked;
  final int minStage;
  final int currentPieces;

  /// 지금 환생하면 얻는 조각.
  final int gain;

  /// 얻는 조각이 1 늘어나는 가장 가까운 스테이지까지 남은 수.
  final int nextPieceInStages;
  final double bonusPerPiece;

  /// 모은 조각 누계 (보너스 근거). [currentPieces]는 쓸 수 있는 조각.
  final int earned;

  double get bonusNow => earned * bonusPerPiece;
  double get bonusAfter => (earned + gain) * bonusPerPiece;
}

RebirthPreview rebirthPreview(GameState s, GameTables t) {
  final r = t.meta.rebirth;
  final stage = s.progress.stage;
  final gain = (piecesFor(t, stage) * pieceGainMultiplier(s, t) * treasurePiecesMultiplier(s, t)).floor();
  var next = stage + 1;
  while (piecesFor(t, next) <= gain) {
    next++;
  }
  return RebirthPreview(
    locked: stage < r.integer('minStage'),
    minStage: r.integer('minStage'),
    currentPieces: s.wallet.mapPieces,
    earned: s.progress.mapPiecesEarned,
    gain: gain,
    nextPieceInStages: next - stage,
    bonusPerPiece: r.number('bonusPerPiece'),
  );
}

/// 환생 (사용자 결정 ①: 이번 회차 스테이지로 매번 전부 지급). 해금 전이면 상태 그대로, 단 [force](운영자)면 진행.
/// 스테이지·골드·배 강화 레벨(능력치)을 초기화하고 선원·도감·젬·증표·최고 기록·명예 외형·스킨·상점은 유지한다.
/// 환생 v2: 상자(젬·영웅 이상 소환)·스킨·칭호·해금을 바로 지급하고 RebirthDone 하나로 알린다.
GameState rebirth(GameState s, SystemContext ctx, {bool force = false}) {
  final t = ctx.tables;
  final p = rebirthPreview(s, t);
  if (p.locked && !force) return s;
  final old = s.battle ?? BattleView.empty;
  final n = s.progress.rebirths + 1;
  final chest = rebirthChest(t, n);
  final got = rebirthRewardsAt(t, n);
  final newSkins = got.skins.where((k) => !s.ship.skinsOwned.contains(k)).toList();
  final newTitles = got.titles.where((k) => !s.progress.titles.contains(k)).toList();
  // 명예 외형: 지금까지 본 최고 단계·등급은 남는다(그림만).
  final look = partLook(s, t);
  final tier = t.shipTiers.tiers.indexOf(t.shipTiers.tierAt(s.progress.bestStage));
  final route = s.progress.treasureRoute;
  var next = s.copyWith(
    wallet: s.wallet.copyWith(gold: BigNum.zero, mapPieces: p.currentPieces + p.gain, gems: s.wallet.gems + chest.gems),
    progress: Progress(
      bestStage: s.progress.bestStage,
      rebirths: n,
      mapPiecesEarned: s.progress.mapPiecesEarned + p.gain,
      titles: [...s.progress.titles, ...newTitles],
      treasureRoute: route,
      bossFails: s.progress.bossFails,
      dex: s.progress.dex,
      collectionClaimed: s.progress.collectionClaimed, // 도감 수집 보상은 환생해도 다시 안 준다
      trialsUsed: s.progress.trialsUsed,
      sailHold: t.waves.rebirthSkip.breakSec > 0, // 빠른 항해가 있으면 '출항!'(StartVoyage)까지 대기 — #19
      treasureSea:
          route != null && route <= treasureSeasUnlocked(s.copyWith(progress: s.progress.copyWith(rebirths: n)), t)
          ? route
          : null,
    ),
    ship: s.ship.copyWith(
      parts: {for (final id in s.ship.parts.keys) id: startLevel(s, t, id)},
      honorParts: {for (final e in look.entries) e.key: e.value},
      honorTier: tier > s.ship.honorTier ? tier : null,
      skinsOwned: {...s.ship.skinsOwned, ...newSkins},
      skin: newSkins.isNotEmpty && !s.ship.skinChosen ? newSkins.first : null,
    ),
    battle: BattleView(tick: old.tick, shipHp: BigNum.one, shipHpMax: BigNum.one, speed: old.speed),
  );
  if (chest.summons > 0) {
    next = summonCards(
      next,
      ctx,
      chest.summons,
      reason: 'rebirth',
      guarantee: t.meta.rebirth.obj('chest').str('minRarity'),
    );
  }
  for (final k in newSkins) {
    ctx.emit(SkinUnlocked(ctx.tick, id: k));
  }
  for (final u in got.unlocks) {
    ctx.emit(ContentUnlocked(ctx.tick, kind: u.kind, value: u.value));
  }
  ctx
    ..emit(
      RebirthDone(
        ctx.tick,
        gain: p.gain,
        pieces: p.currentPieces + p.gain,
        rebirths: n,
        gems: chest.gems,
        summons: chest.summons,
        title: newTitles.firstOrNull,
        skin: newSkins.firstOrNull,
      ),
    )
    ..emit(SaveRequested(ctx.tick, reason: 'rebirth'));
  return next;
}

GameState onRebirth(GameState s, Rebirth c, SystemContext ctx) => rebirth(s, ctx);

GameState opRebirthNow(GameState s, OpRebirthNow c, SystemContext ctx) => rebirth(s, ctx, force: true);

/// 운영자: 새 게임 (playerId·설정·운영자 표시는 유지).
GameState opReset(GameState s, OpReset c, SystemContext ctx) => GameState.newGame(
  playerId: s.playerId,
  seed: s.rngSeed,
  now: ctx.clock.now(),
  crews: ctx.tables.meta.startingCrews,
).copyWith(settings: s.settings, operator: true);
