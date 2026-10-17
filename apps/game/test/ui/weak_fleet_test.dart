import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/crew/weak_fleet.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';

import 'ui_harness.dart';

// 약점 편성 (S1 2026-10-18): 약점 계열 먼저(파워순) · 계열 상한 · 칸마다 SetFleetSlot · 카드 '약점!' 배지 · 다음 보스 칸.

final _t = GameTables.load();

void main() {
  test('약점 계열이 먼저, 같은 계열은 상한까지', () {
    final s = loadFixture('stage37_midgame');
    final owned = s.crews.keys.map(_t.crews.byId).toList();
    final weak = {owned.last.family};
    final out = weakFleet(s, _t, 3, weak);
    expect(_t.crews.byId(out.first).family, owned.last.family);
    final perFamily = <String, int>{};
    for (final id in out) {
      perFamily.update(_t.crews.byId(id).family, (n) => n + 1, ifAbsent: () => 1);
    }
    expect(perFamily.values.every((n) => n <= _t.skills.maxSameFamilyInFleet), isTrue);
  });

  testWidgets('선원 탭: 다음 보스 칸 · 약점 배지 · [약점 편성] → SetFleetSlot', (tester) async {
    final s = loadFixture('stage37_midgame');
    final log = await pumpGame(tester, s, tab: crewTab);
    expect(find.byKey(const Key('fleet.nextBoss')), findsOneWidget);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final weak = c.read(weakFamiliesProvider);
    expect(weak, isNotEmpty, reason: 'stage37 다음 보스는 약점이 있다');
    final ownedWeak = s.crews.keys.where((id) => weak.contains(_t.crews.byId(id).family));
    if (ownedWeak.isNotEmpty) {
      expect(find.byKey(Key('crew.weak.${ownedWeak.first}'), skipOffstage: false), findsOneWidget);
    }
    final slots = c.read(fleetSlotsProvider);
    final target = weakFleet(s, _t, slots.length, weak);
    await tester.tap(find.byKey(const Key('fleet.weak')));
    await tester.pump();
    final changed = [
      for (var i = 0; i < target.length; i++)
        if (slots[i] != target[i]) i,
    ];
    expect(log.sent.whereType<SetFleetSlot>().map((e) => e.slot), changed);
    await tester.pump(const Duration(seconds: 3));
  });
}
