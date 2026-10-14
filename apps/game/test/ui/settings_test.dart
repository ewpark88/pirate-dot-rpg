import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

GameState _withSetting(GameState s, String key, Object value) => s.copyWith(settings: s.settings.withValue(key, value));

const _switches = ['bgm', 'sfx', 'vibration', 'shake', 'flash', 'powerSave', 'autoBoss', 'autoUpgrade'];

Future<CommandLog> _openSettings(WidgetTester tester, GameState state) async {
  final log = await pumpGame(tester, state);
  await tester.tap(find.byKey(const Key('hud.settings')));
  await tester.pumpAndSettle();
  return log;
}

void main() {
  testWidgets('기준 7: 톱니 → 설정 9항목, 흔들림 끄기 → SetSetting(shake, false)', (tester) async {
    final log = await _openSettings(tester, loadFixture('stage37_midgame'));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('settings.lang')), findsOneWidget);
    for (final k in _switches) {
      expect(find.byKey(Key('settings.$k'), skipOffstage: false), findsOneWidget, reason: k);
    }
    await tester.tap(find.byKey(const Key('settings.shake')));
    expect(log.sent.map((c) => c.toJson()), [const SetSetting('shake', false).toJson()]);
  });

  testWidgets('기준 8: English 선택 → SetSetting(lang, en)', (tester) async {
    final log = await _openSettings(tester, loadFixture('stage37_midgame'));
    await tester.tap(find.text('English'));
    expect(log.sent.map((c) => c.toJson()), [const SetSetting('lang', 'en').toJson()]);
  });

  testWidgets('기준 8: settings.lang = en이면 한국어 OS에서도 영어 화면', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpGame(tester, _withSetting(loadFixture('stage37_midgame'), 'lang', 'en'), locale: null);
    expect(find.text('Ship'), findsOneWidget);
  });

  testWidgets('기준 8: settings.lang = system이면 OS 언어(한국어)', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpGame(tester, loadFixture('stage37_midgame'), locale: null);
    expect(find.text('배'), findsOneWidget);
  });

  testWidgets('기준 9: 설정이 바뀌면 전장 JuiceSettings가 따라온다', (tester) async {
    final container = ProviderContainer(
      overrides: [initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame'))],
    );
    addTearDown(container.dispose);
    final game = container.read(battleGameProvider);
    expect((game.settings.shake, game.settings.flash, game.settings.vibration), (true, true, true));

    var s = container.read(gameStateProvider);
    for (final (k, v) in [('shake', false), ('flash', false), ('vibration', false), ('powerSave', false)]) {
      s = _withSetting(s, k, v);
    }
    container.read(gameStateProvider.notifier).replace(s);
    expect(
      (game.settings.shake, game.settings.flash, game.settings.vibration, game.settings.powerSave),
      (false, false, false, false),
    );
  });
}
