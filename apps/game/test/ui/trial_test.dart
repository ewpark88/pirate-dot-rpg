import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'package:pirate_dot/ui/meta/trial_gate.dart';

import 'ui_harness.dart';

// 맛보기 팝업 (사용자 2026-10-17, S2 meta.trials · ClaimTrial): 최고 스테이지 5 이상이면 '2배속 10분 무료 체험',
// [무료로 써 보기] → ClaimTrial(speed), [나중에]는 이번 실행에서 다시 묻지 않음.

GameState _at(int best) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(bestStage: best, bossFails: 0, trialsUsed: const []),
  );
}

/// 조용한 시간(trialQuietSec)이 지나 팝업이 뜰 때까지.
Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i <= trialQuietSec + 1; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('스테이지 5 넘음 → 2배속 체험 팝업 → 무료로 써 보기 = ClaimTrial(speed)', (tester) async {
    final log = await pumpGame(tester, _at(37), openTab: false, trials: true);
    await _wait(tester);
    expect(find.byKey(const Key('trial.offer.speed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trial.try')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(log.sent.whereType<ClaimTrial>().single.kind, 'speed');
  });

  testWidgets('나중에 → 같은 실행에선 다시 안 뜬다', (tester) async {
    await pumpGame(tester, _at(37), openTab: false, trials: true);
    await _wait(tester);
    await tester.tap(find.byKey(const Key('trial.later')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('trial.offer.speed')), findsNothing);
  });

  testWidgets('조용한 시간 전엔 안 뜬다 · 한 실행에 하나(자동 강화 조건도 맞아도 2배속 하나만)', (tester) async {
    final s = _at(37);
    await pumpGame(tester, s.copyWith(progress: s.progress.copyWith(bossFails: 3)), openTab: false, trials: true);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const Key('trial.offer.speed')), findsNothing);
    await _wait(tester);
    await tester.tap(find.byKey(const Key('trial.later')));
    await _wait(tester);
    await _wait(tester);
    expect(find.byKey(const Key('trial.offer.autoUpgrade')), findsNothing);
  });

  testWidgets('조건이 안 맞으면(최고 스테이지 1) 팝업 없음', (tester) async {
    await pumpGame(tester, _at(1), openTab: false);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('trial.offer.speed')), findsNothing);
  });
}
