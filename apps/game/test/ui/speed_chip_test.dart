import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'ui_harness.dart';

// 2배속 칩 (사용자 2026-10-18 '속도 ×2 효과가 밋밋, 사서 쓰고 싶게'): 유료 2배속·순풍이 켜져 있으면 금빛 큰 ×2 · 바람 고리,
// 켜지는 순간 효과 한 줄 토스트.

void main() {
  testWidgets('유료 2배속 권리 → 칩 ×2 · 바람 고리', (tester) async {
    final s = loadFixture('stage37_midgame');
    final at = s.savedAt.toUtc();
    final paid = s.copyWith(
      buffs: const Buffs(),
      entitlements: {'speed': Entitlement(since: at)},
    );
    await pumpGame(tester, paid, openTab: false);
    expect(find.byKey(const Key('tailwind.speed')), findsOneWidget);
    expect(find.text('×2'), findsWidgets);
    expect(find.byKey(const Key('tailwind.ring')), findsOneWidget);
    expect(find.byKey(const Key('tailwind.bar')), findsNothing); // 영구는 남은 시간 없음
  });

  testWidgets('순풍이 켜지는 순간 토스트 "Tailwind! Speed ×2 · Gold ×2"', (tester) async {
    final s = loadFixture('stage37_midgame');
    final off = s.copyWith(buffs: const Buffs());
    await pumpGame(tester, off, openTab: false);
    expect(find.byKey(const Key('tailwind.speed')), findsNothing);
    replaceState(tester, s); // 샘플은 순풍 1:30 남음
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Tailwind!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
