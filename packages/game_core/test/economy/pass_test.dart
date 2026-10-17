import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/src/economy/pass.dart' show passTick;
import 'package:test/test.dart';

import 'harness.dart';

/// 항해 패스(iap.json pass): 처음 깬 스테이지·퀘스트·출석으로 경험치, 단계마다 무료 줄(누구나)·유료 줄(pass 권리), 시즌이 바뀌면 처음부터.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final pass = t.iap.pass;

  GameState at(EconomyHarness h, int best) => passTick(
    h.newGame().copyWith(
      progress: Progress(stage: best, bestStage: best),
    ),
    t,
  );

  test('처음 깬 스테이지만큼 경험치 — 시작 때 최고 스테이지는 세지 않는다', () {
    final h = EconomyHarness();
    final s0 = at(h, 10);
    expect(passOf(s0, t).xp, 0);
    final s = passTick(s0.copyWith(progress: s0.progress.copyWith(stage: 35, bestStage: 35)), t);
    expect(passOf(s, t).xp, 25 * pass.xp['stage']!);
    expect(passLevel(s, t), 25 * pass.xp['stage']! ~/ pass.xpPerLevel);
    expect(GameState.fromJson(s.toJson()).pass!.xp, passOf(s, t).xp);
  });

  test('무료 줄은 누구나 한 단계씩, 유료 줄은 pass 권리가 있어야', () {
    final h = EconomyHarness();
    final s0 = at(h, 1);
    final s1 = s0.copyWith(pass: passOf(s0, t).copyWith(xp: pass.xpPerLevel * 2));
    var s = sys.handle(s1, const ClaimPassReward(paid: false), h.ctx)!;
    expect(passOf(s, t).free, 1);
    s = sys.handle(s, const ClaimPassReward(paid: false), h.ctx)!;
    expect(passOf(s, t).free, 2);
    expect(identical(sys.handle(s, const ClaimPassReward(paid: false), h.ctx), s), isTrue, reason: '3단계는 아직');
    expect(identical(sys.handle(s, const ClaimPassReward(paid: true), h.ctx), s), isTrue, reason: '권리 없음');
    final bought = sys.handle(s, GrantPurchase('voyage_pass', 'tok', EconomyHarness.start), h.ctx)!;
    s = sys.handle(bought, const ClaimPassReward(paid: true), h.ctx)!;
    expect(passOf(s, t).paid, 1);
    expect(h.of<PassRewardClaimed>().map((e) => (e.level, e.paid)), [(1, false), (2, false), (1, true)]);
  });

  test('시즌 id가 바뀌면 진행이 처음부터', () {
    final h = EconomyHarness();
    final s0 = at(h, 1);
    final old = s0.copyWith(pass: const PassState(season: 'old', xp: 999, free: 5));
    expect(passOf(old, t).season, pass.season);
    expect(passOf(old, t).xp, 0);
  });

  test('무료 줄 30단계 = 하루 성실 플레이(퀘스트 3·출석 1·새 스테이지 몇 개)로 30일 안 — 필요 경험치 확인', () {
    final need = pass.xpPerLevel * pass.free.length;
    final perDay = 3 * pass.xp['quest']! + pass.xp['attendance']!;
    expect(perDay * 30, greaterThanOrEqualTo(need * 0.8), reason: '퀘스트·출석만으로도 80% 이상(새 스테이지로 나머지)');
  });
}
