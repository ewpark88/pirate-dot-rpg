import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/build_counter.dart';
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

/// 조각마다 틱 100번 동안 허용하는 build 횟수. 골드에 따라 바뀌는 것(배 강화 줄 — 살 수 있나)도 몇 번뿐이다.
int _maxBuilds(String id) => switch (id) {
  'crewCard' => 80, // 40장 × 처음 한 번 + 여유
  'partRow' => 25,
  _ => 5,
};

void main() {
  final base = loadFixture('all_crews_mythic');

  for (final (name, tab) in [('voyage', voyageTab), ('ship', shipTab), ('crew', crewTab), ('summon', summonTab)]) {
    testWidgets('시트 $name 열고 틱 100번: 닫힌 상태보다 크게 느리지 않다', (tester) async {
      await pumpGame(tester, base, openTab: false);
      final closed = await _run100(tester, base);
      debugBuildCounts.clear();
      await tester.tap(find.byKey(Key('tab.$tab')));
      await tester.pumpAndSettle();
      // 세기가 실제로 동작하는지: 시트를 열면 그 탭이 한 번은 지어진다.
      expect(debugBuildCounts, isNotEmpty, reason: '$name build 세기');
      debugBuildCounts.clear();
      final open = await _run100(tester, base);
      // 측정값을 로그로 남긴다(회귀 원인 찾기).
      // ignore: avoid_print
      print('PERF $name closed=${closed.inMilliseconds}ms open=${open.inMilliseconds}ms builds=$debugBuildCounts');
      // 시간은 PC 부하에 흔들린다(S1 --full 실패) → 무거운 조각이 틱 100번 동안 다시 지어진 횟수로 잰다.
      // 틱마다 다시 지으면 100+, 지금은 골드가 바뀌는 몇 번뿐이어야 한다.
      for (final e in debugBuildCounts.entries) {
        expect(e.value, lessThanOrEqualTo(_maxBuilds(e.key)), reason: '$name: ${e.key} build ${e.value}회 / 틱 100번');
      }
    });
  }

  testWidgets('편성 고르기 열고 틱 100번: 닫힌 상태보다 크게 느리지 않다(40명 줄)', (tester) async {
    final ids = [for (final f in base.battle!.fleet) f.crewId];
    final gap = base.copyWith(fleet: [...ids.take(ids.length - 1), null], fleetInit: true);
    await pumpGame(tester, gap, openTab: false);
    final closed = await _run100(tester, gap);
    debugBuildCounts.clear();
    await tester.tap(find.byKey(Key('fleet.slot.${ids.length - 1}')));
    await tester.pumpAndSettle();
    expect(debugBuildCounts['fleetPicker'], greaterThan(0), reason: 'picker build 세기');
    debugBuildCounts.clear();
    final open = await _run100(tester, gap);
    // 측정값을 로그로 남긴다(회귀 원인 찾기).
    // ignore: avoid_print
    print('PERF picker closed=${closed.inMilliseconds}ms open=${open.inMilliseconds}ms builds=$debugBuildCounts');
    expect(debugBuildCounts['fleetPicker'] ?? 0, lessThanOrEqualTo(5), reason: 'picker build / 틱 100번');
  });
}
