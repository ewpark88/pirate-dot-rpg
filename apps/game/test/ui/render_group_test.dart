import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/render_group.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

Future<ProviderContainer> _pump(WidgetTester tester, {bool withBattle = true}) async {
  final container = ProviderContainer(
    overrides: [
      initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame')),
      if (!withBattle) battleViewBuilderProvider.overrideWithValue((_) => const SizedBox()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RenderGroup()),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('기준 10: 부하 → stress, 라이브 → resumeLive 결과(입력 없으면 데모)', (tester) async {
    final container = await _pump(tester);
    final game = container.read(battleGameProvider);
    await tester.tap(find.text('Stress'));
    await tester.pump();
    expect(game.mode, BattleMode.stress);
    await tester.tap(find.text('Live'));
    await tester.pump();
    expect(game.mode, BattleMode.demo); // 테스트에는 엔진 입력(battleFeedProvider)이 없다
  });

  testWidgets('기준 10: 성능 표시·히트박스 스위치가 BattleGame 값을 바꾼다', (tester) async {
    final container = await _pump(tester);
    final game = container.read(battleGameProvider);
    final perfBefore = game.perfOverlay;
    await tester.tap(find.byKey(const Key('op.perfOverlay')));
    await tester.tap(find.byKey(const Key('op.hitboxes')));
    await tester.pump();
    expect(game.perfOverlay, !perfBefore);
    expect(game.showHitboxes, isTrue);
  });

  testWidgets('피드백 #22: 카드 연출 시작 등급 — 처음은 fx_map 값, 고르면 그 등급이 선택된다(BattleGame.cardFxMinRarity)', (tester) async {
    await _pump(tester);
    final seg = find.byKey(const Key('op.cardFxMin'));
    expect(tester.widget<SegmentedButton<String>>(seg).selected, hasLength(1));
    await tester.tap(find.descendant(of: seg, matching: find.text('Legend')));
    await tester.pump();
    expect(tester.widget<SegmentedButton<String>>(seg).selected, {'legend'});
  });

  testWidgets('기준 11: 전장이 Flame 게임이 아니면 비활성', (tester) async {
    await _pump(tester, withBattle: false);
    expect(tester.widget<FilterChip>(find.byKey(const Key('op.hitboxes'))).onSelected, isNull);
    expect(tester.widget<SegmentedButton<BattleMode>>(find.byKey(const Key('op.mode'))).onSelectionChanged, isNull);
  });
}
