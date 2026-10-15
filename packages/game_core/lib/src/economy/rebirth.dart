import 'dart:math' as math;

import 'package:game_core/src/bignum/big_num.dart';
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
  final gain = piecesFor(t, stage);
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
/// 스테이지·골드·배 강화를 초기화하고 선원·도감·젬·증표·최고 기록은 유지한다.
GameState rebirth(GameState s, SystemContext ctx, {bool force = false}) {
  final t = ctx.tables;
  final p = rebirthPreview(s, t);
  if (p.locked && !force) return s;
  final old = s.battle ?? BattleView.empty;
  ctx
    ..emit(
      RebirthDone(ctx.tick, gain: p.gain, pieces: p.currentPieces + p.gain, rebirths: s.progress.rebirths + 1),
    )
    ..emit(SaveRequested(ctx.tick, reason: 'rebirth'));
  return s.copyWith(
    wallet: s.wallet.copyWith(gold: BigNum.zero, mapPieces: p.currentPieces + p.gain),
    progress: Progress(
      bestStage: s.progress.bestStage,
      rebirths: s.progress.rebirths + 1,
      mapPiecesEarned: s.progress.mapPiecesEarned + p.gain,
      titles: s.progress.titles,
      treasureRoute: s.progress.treasureRoute,
    ),
    ship: ShipState(parts: {for (final id in s.ship.parts.keys) id: 0}),
    battle: BattleView(tick: old.tick, shipHp: BigNum.one, shipHpMax: BigNum.one, speed: old.speed),
  );
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
