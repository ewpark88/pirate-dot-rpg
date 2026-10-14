import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/src/economy/rebirth.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-rebirth 수용 기준 1~5.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final r = t.meta.rebirth;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  int pieces(int stage) => math.pow(stage - r.integer('offset'), r.number('exponent')).floor();

  GameState at(int stage, {int pieces = 0}) => h
      .newGame(gold: BigNum.from(1e6), gems: 77)
      .copyWith(
        progress: Progress(stage: stage, bestStage: stage + 5, wave: 2, farming: true),
        ship: const ShipState(parts: {'cannon': 30, 'hull': 20, 'sail': 5, 'crowsnest': 3, 'cargo': 9}),
        crews: {'octo': const CrewState(level: 33, cards: 2)},
        collection: {'octo'},
        tokens: 4,
        wallet: Wallet(gold: BigNum.from(1e6), gems: 77, mapPieces: pieces),
        battle: BattleView.empty,
        clearTutorial: true,
      );

  test('조각 공식 floor((stage − 35)^1.4): 40 → 9, 50 → 44', () {
    expect(piecesFor(t, 40), 9);
    expect(piecesFor(t, 50), 44);
    expect(piecesFor(t, 30), 0);
  });

  test('기준 1: 스테이지 39면 환생 안 됨', () {
    final s0 = at(r.integer('minStage') - 1);
    final s = sys.handle(s0, const Rebirth(), h.ctx)!;
    expect(s.progress.stage, s0.progress.stage);
    expect(h.events, isEmpty);
  });

  test('기준 2: 스테이지 50 → 조각 +44, 스테이지·골드·배 초기화, 선원·젬·증표·도감·최고 기록 유지', () {
    final s = sys.handle(at(50, pieces: 3), const Rebirth(), h.ctx)!;
    expect(s.wallet.mapPieces, 3 + pieces(50));
    expect(s.wallet.gold, BigNum.zero);
    expect(s.wallet.gems, 77);
    expect(s.ship.parts.values.every((lv) => lv == 0), isTrue);
    expect(s.progress.stage, 1);
    expect(s.progress.wave, 0);
    expect(s.progress.farming, isFalse);
    expect(s.progress.rebirths, 1);
    expect(s.progress.bestStage, 55);
    expect(s.crews['octo']!.level, 33);
    expect(s.tokens, 4);
    expect(s.collection, {'octo'});
    expect(h.of<SaveRequested>().map((e) => e.reason), contains('rebirth'));
  });

  test('기준 3: 미리보기 = 처리와 같은 계산, 잠겨 있어도 값을 준다', () {
    final p = rebirthPreview(at(50, pieces: 3), t);
    expect(p.locked, isFalse);
    expect(p.gain, pieces(50));
    expect(p.currentPieces, 3);
    var next = 51;
    while (pieces(next) <= pieces(50)) {
      next++;
    }
    expect(p.nextPieceInStages, next - 50);
    expect(p.bonusNow, closeTo(3 * r.number('bonusPerPiece'), 1e-12));
    expect(p.bonusAfter, closeTo((3 + pieces(50)) * r.number('bonusPerPiece'), 1e-12));
    final locked = rebirthPreview(at(10), t);
    expect(locked.locked, isTrue);
    expect(locked.gain, 0);
    expect(locked.minStage, r.integer('minStage'));
  });

  test('기준 4: 보너스 = 조각 × 0.05, 초당 골드 추정에 더해진다', () {
    expect(rebirthBonus(at(50, pieces: 10), t), closeTo(0.5, 1e-12));
    final base = at(50);
    final boosted = at(50, pieces: 10);
    final fleet = offlineFleet(base, t);
    final ratio = (goldPerSecEstimate(boosted, t, fleet) / goldPerSecEstimate(base, t, fleet)).toDouble();
    expect(ratio, greaterThan(1.5 - 1e-9));
  });

  test('기준 5: OpRebirthNow는 해금 무시(조각은 공식대로), OpReset은 새 게임', () {
    final now = sys.handle(at(20), const OpRebirthNow(), h.ctx)!;
    expect(now.progress.rebirths, 1);
    expect(now.wallet.mapPieces, 0);
    final reset = sys.handle(at(50, pieces: 9), const OpReset(), h.ctx)!;
    expect(reset.tutorialStep, 1);
    expect(reset.wallet.mapPieces, 0);
    expect(reset.crews.keys.toSet(), t.meta.startingCrews.toSet());
    expect(reset.playerId, 'test');
  });
}
