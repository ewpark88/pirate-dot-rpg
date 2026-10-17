import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 배 스킨 얻는 길 (docs/specs/economy-ship-skins.md, S1 결정): 꾸밈만 — 도감 10·스테이지 100·현상금 단계 10·현상금 전부 5·스테이지 300·도감 40 자동, 조각 50 사기.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;

  GameState owning(EconomyHarness h, int n, {int best = 1}) {
    final ids = [for (final c in t.crews.crews.take(n)) c.id];
    return h.newGame().copyWith(
      crews: {for (final id in ids) id: const CrewState()},
      collection: ids.toSet(),
      progress: Progress(stage: best, bestStage: best),
    );
  }

  test('표: 7종, 사용자 결정 순서·조건', () {
    final v = shipSkinsView(owning(EconomyHarness(), 1), t);
    expect(v.map((x) => (x.type, x.value)), [
      ('collection', 10),
      ('bestStage', 100),
      ('bountyTier', 10),
      ('bountyAll', 5),
      ('bestStage', 300),
      ('collection', 40),
      ('pieces', 50),
    ]);
  });

  test('자동: 도감 10명 → 다음 틱 SkinUnlocked 한 번, 이미 있으면 다시 안 냄 · 스테이지 100(소급)', () {
    final h = EconomyHarness();
    final s = sys.update(owning(h, 10), h.ctx);
    expect(h.of<SkinUnlocked>().map((e) => e.id), ['king']);
    expect(s.ship.skinsOwned, contains('king'));
    sys.update(s, h.ctx);
    expect(h.of<SkinUnlocked>(), hasLength(1));
    final h2 = EconomyHarness();
    final old = sys.update(owning(h2, 2, best: 320), h2.ctx);
    expect(old.ship.skinsOwned, containsAll(['fairy', 'ghostship']), reason: '옛 세이브 소급');
  });

  test('현상금: 아무 보스 단계 10 · 모든 보스 단계 5', () {
    final h = EconomyHarness();
    final bosses = [for (final d in t.meta.raw.obj('bounty').objs('days')) d.str('boss')];
    final one = owning(h, 1).copyWith(bounty: BountyState(cleared: {bosses.first: 10}));
    expect(sys.update(one, h.ctx).ship.skinsOwned, contains('frost'));
    final all = owning(h, 1).copyWith(bounty: BountyState(cleared: {for (final b in bosses) b: 5}));
    expect(sys.update(all, h.ctx).ship.skinsOwned, contains('lava'));
    final most = owning(h, 1).copyWith(bounty: BountyState(cleared: {for (final b in bosses.skip(1)) b: 5}));
    expect(sys.update(most, h.ctx).ship.skinsOwned, isNot(contains('lava')));
  });

  test('조각 스킨: 50 조각으로 사기(자동 아님), 모자라면 그대로 · 명령 JSON 왕복', () {
    final h = EconomyHarness();
    final rich = owning(h, 1).copyWith(wallet: owning(h, 1).wallet.copyWith(mapPieces: 60));
    expect(sys.update(rich, h.ctx).ship.skinsOwned, isNot(contains('abyss')));
    final bought = sys.handle(rich, const BuySkin('abyss'), h.ctx)!;
    expect((bought.wallet.mapPieces, bought.ship.skinsOwned.contains('abyss')), (10, true));
    final poor = owning(h, 1).copyWith(wallet: owning(h, 1).wallet.copyWith(mapPieces: 49));
    expect(sys.handle(poor, const BuySkin('abyss'), h.ctx), poor);
    expect(Command.fromJson(const BuySkin('x').toJson()).toJson(), const BuySkin('x').toJson());
  });
}
