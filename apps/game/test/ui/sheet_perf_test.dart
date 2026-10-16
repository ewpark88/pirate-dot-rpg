import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 사용자 긴급 버그 2026-10-16: '모두 신화' 상태에서 시트(선원·배·항해·도감)를 열면 전투가 버벅인다.
// 엔진 틱(50ms)마다 상태가 바뀐다 → 시트가 틱마다 무거운 계산·재빌드를 하면 안 된다. 틱 100번의 처리 시간을 잰다.

/// 틱마다 바뀌는 값만 바꾼 다음 상태 (전투 틱 · 골드 조금).
GameState _tick(GameState s, int n) => s.copyWith(
  wallet: s.wallet.copyWith(gold: s.wallet.gold + BigNum.from(n)),
  battle: s.battle!.copyWith(tick: (s.battle!.tick) + n),
);

Future<Duration> _run100(WidgetTester tester, GameState base) async {
  final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  final sw = Stopwatch()..start();
  for (var i = 1; i <= 100; i++) {
    c.read(gameStateProvider.notifier).replace(_tick(base, i));
    await tester.pump(const Duration(milliseconds: 50));
  }
  sw.stop();
  return sw.elapsed;
}

void main() {
  final base = loadFixture('all_crews_mythic');

  for (final (name, tab) in [('voyage', voyageTab), ('ship', shipTab), ('crew', crewTab), ('summon', summonTab)]) {
    testWidgets('시트 $name 열고 틱 100번: 닫힌 상태보다 크게 느리지 않다', (tester) async {
      await pumpGame(tester, base, openTab: false);
      final closed = await _run100(tester, base);
      await tester.tap(find.byKey(Key('tab.$tab')));
      await tester.pumpAndSettle();
      final open = await _run100(tester, base);
      // 측정값을 로그로 남긴다(회귀 원인 찾기).
      // ignore: avoid_print
      print('PERF $name closed=${closed.inMilliseconds}ms open=${open.inMilliseconds}ms');
      // 시트가 틱마다 하는 일은 작아야 한다: 틱당 평균 추가 시간 ≤ 4ms (테스트 기계 기준, 여유 큼).
      expect((open - closed).inMicroseconds / 100, lessThan(4000), reason: '$name 틱당 추가 처리 시간');
    });
  }

  testWidgets('편성 고르기 열고 틱 100번: 닫힌 상태보다 크게 느리지 않다(40명 줄)', (tester) async {
    final ids = [for (final f in base.battle!.fleet) f.crewId];
    final gap = base.copyWith(fleet: [...ids.take(ids.length - 1), null], fleetInit: true);
    await pumpGame(tester, gap, openTab: false);
    final closed = await _run100(tester, gap);
    await tester.tap(find.byKey(Key('fleet.slot.${ids.length - 1}')));
    await tester.pumpAndSettle();
    final open = await _run100(tester, gap);
    // 측정값을 로그로 남긴다(회귀 원인 찾기).
    // ignore: avoid_print
    print('PERF picker closed=${closed.inMilliseconds}ms open=${open.inMilliseconds}ms');
    expect((open - closed).inMicroseconds / 100, lessThan(4000), reason: 'picker 틱당 추가 처리 시간');
  });
}
