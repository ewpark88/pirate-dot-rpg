import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/hud/coin_arrival.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 코인 도착 (렌더 coinFlow 계약): 표시 골드 = 지갑 − 날아오는 중, 닿을 때마다 '+금액'(연달아 닿으면 합침).

GameState _with(GameState s, {BigNum? gold, int? tick}) => s.copyWith(
  wallet: gold == null ? null : s.wallet.copyWith(gold: gold),
  battle: tick == null ? null : s.battle!.copyWith(tick: tick),
);

void main() {
  test('지갑이 오르면 붙잡고, 닿은 만큼 놓고, 1.2초 동안 안 닿으면 전부 놓는다', () {
    final s = loadFixture('stage37_midgame');
    final c = ProviderContainer(
      overrides: [
        initialGameStateProvider.overrideWithValue(_with(s, tick: 100)),
        hasBattleGameProvider.overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    final gold = s.wallet.gold;
    c.read(coinFxProvider);
    expect(c.read(displayGoldProvider), gold);

    final game = c.read(gameStateProvider.notifier)..replace(_with(s, gold: gold + BigNum.from(500), tick: 101));
    expect(c.read(displayGoldProvider), gold);
    c.read(coinFxProvider.notifier).arrive(BigNum.from(200));
    expect(c.read(displayGoldProvider), gold + BigNum.from(200));
    expect(c.read(coinFxProvider).merged, BigNum.from(200));
    c.read(coinFxProvider.notifier).arrive(BigNum.from(100));
    expect(c.read(coinFxProvider).merged, BigNum.from(300), reason: '0.6초 안이면 합친다');

    game.replace(_with(s, gold: gold + BigNum.from(500), tick: 140));
    expect(c.read(displayGoldProvider), gold + BigNum.from(500));
  });

  test('실제 전장이 없으면(테스트·빈 전장) 붙잡지 않는다', () {
    final s = loadFixture('stage37_midgame');
    final c = ProviderContainer(
      overrides: [initialGameStateProvider.overrideWithValue(s), hasBattleGameProvider.overrideWithValue(false)],
    );
    addTearDown(c.dispose);
    c.read(coinFxProvider);
    c.read(gameStateProvider.notifier).replace(_with(s, gold: s.wallet.gold + BigNum.from(500)));
    expect(c.read(displayGoldProvider), s.wallet.gold + BigNum.from(500));
  });

  testWidgets('닿으면 골드 아이콘 옆에 +금액이 잠깐 뜬다', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    c.read(coinFxProvider.notifier).arrive(BigNum.from(1500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+${BigNum.from(1500).format()}'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('top.gold.plus')), findsNothing);
  });
}
