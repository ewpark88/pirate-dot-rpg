import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/src/economy/trials.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 맛보기(meta.trials, 사용자 요청 2026-10-17): 2배속(스테이지 5)·자동 강화(첫 보스 실패 뒤)를 계정당 1회씩 10분 무료.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final trials = t.meta.raw.obj('trials');

  GameState at(EconomyHarness h, {int best = 1, int fails = 0}) => h.newGame().copyWith(
    progress: Progress(stage: best, bestStage: best, bossFails: fails),
  );

  test('조건 전엔 못 받고, 맞으면 한 번만 — 2배속은 순풍, 자동 강화는 자동 강화 버프', () {
    final h = EconomyHarness();
    final speedAt = trials.obj('speed').integer('atStage');
    expect(trialsReady(at(h, best: speedAt - 1), t), isEmpty);
    expect(trialsReady(at(h, best: speedAt, fails: 1), t), ['speed', 'autoUpgrade']);

    var s = sys.handle(at(h, best: speedAt), const ClaimTrial('speed'), h.ctx)!;
    expect(tailwindRemaining(s, h.clock.now()).inSeconds, trials.obj('speed').integer('durationSec'));
    expect(s.progress.trialsUsed, ['speed']);
    expect(h.of<TrialClaimed>().single.kind, 'speed');
    expect(identical(sys.handle(s, const ClaimTrial('speed'), h.ctx), s), isTrue, reason: '두 번째는 그대로');

    s = sys.handle(s.copyWith(progress: s.progress.copyWith(bossFails: 1)), const ClaimTrial('autoUpgrade'), h.ctx)!;
    expect(autoUpgradeRemaining(s, h.clock.now()).inSeconds, trials.obj('autoUpgrade').integer('durationSec'));
    expect(s.progress.trialsUsed, ['speed', 'autoUpgrade']);
  });

  test('받은 맛보기는 세이브·환생을 지나도 남는다', () {
    final h = EconomyHarness();
    final s = sys.handle(at(h, best: 50), const ClaimTrial('speed'), h.ctx)!;
    expect(GameState.fromJson(s.toJson()).progress.trialsUsed, ['speed']);
    final reborn = sys.handle(s, const Rebirth(), h.ctx) ?? s;
    expect(reborn.progress.trialsUsed, ['speed']);
  });
}
