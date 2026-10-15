import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 상단 골드는 지갑 값 그대로 실시간 (사용자 지시 2026-10-15: 통통·'+금액' 연출 없음).

void main() {
  testWidgets('지갑 골드가 바뀌면 상단 골드가 바로 바뀌고 +금액은 뜨지 않는다', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final more = s.wallet.gold + BigNum.from(1e6);
    c.read(gameStateProvider.notifier).replace(s.copyWith(wallet: s.wallet.copyWith(gold: more)));
    await tester.pump();
    expect(find.text(more.format()), findsWidgets);
    expect(find.byKey(const Key('top.gold.plus')), findsNothing);
  });
}
