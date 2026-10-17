import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/idle.dart';

import 'ui_harness.dart';

GameState _withSetting(GameState s, String key, Object value) => s.copyWith(settings: s.settings.withValue(key, value));

const _switches = [
  'bgm',
  'sfx',
  'vibration',
  'shake',
  'flashLevel',
  'powerSave',
  'sleepAfter',
  'autoBoss',
  'notifications',
];

Future<CommandLog> _openSettings(WidgetTester tester, GameState state) async {
  final log = await pumpGame(tester, state);
  await tester.tap(find.byKey(const Key('hud.settings')));
  await tester.pumpAndSettle();
  return log;
}

void main() {
  testWidgets('기준 7: 톱니 → 설정 8항목(자동 강화 토글 없음), 흔들림 끄기 → SetSetting(shake, false)', (tester) async {
    final log = await _openSettings(tester, loadFixture('stage37_midgame'));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('settings.lang')), findsOneWidget);
    for (final k in _switches) {
      expect(find.byKey(Key('settings.$k'), skipOffstage: false), findsOneWidget, reason: k);
    }
    await tester.tap(find.byKey(const Key('settings.shake')));
    expect(log.sent.map((c) => c.toJson()), [const SetSetting('shake', false).toJson()]);
  });

  testWidgets('번쩍임 끔/약/강(기본 약): 강 → SetSetting(flashLevel, full)', (tester) async {
    final log = await _openSettings(tester, loadFixture('stage37_midgame'));
    final row = find.byKey(const Key('settings.flashLevel'));
    await tester.scrollUntilVisible(row, 100);
    await tester.tap(find.descendant(of: row, matching: find.text('Full')));
    expect(log.sent.map((c) => c.toJson()), [const SetSetting('flashLevel', 'full').toJson()]);
  });

  testWidgets('절전 화면까지 1/5/10/20/30분(기본 10): 30분 → SetSetting(sleepAfterSec, 1800), 절전 모드 끔이면 못 고름', (tester) async {
    final log = await _openSettings(tester, loadFixture('stage37_midgame'));
    final row = find.byKey(const Key('settings.sleepAfter'));
    await tester.scrollUntilVisible(row, 100);
    await tester.tap(find.descendant(of: row, matching: find.text('30 min')));
    expect(log.sent.map((c) => c.toJson()), [const SetSetting('sleepAfterSec', 1800).toJson()]);

    final off = await _openSettings(tester, _withSetting(loadFixture('stage37_midgame'), 'powerSave', false));
    await tester.scrollUntilVisible(row, 100);
    await tester.tap(find.descendant(of: row, matching: find.text('1 min')));
    expect(off.sent, isEmpty);
  });

  test('절전 화면 시간: 절전 모드 켬일 때만, 옛 값은 가장 가까운 선택지(180 → 5분, 0 → 1분), 기본 10분', () {
    expect(sleepAfterOf(powerSave: true, sec: 60), const Duration(minutes: 1));
    expect(sleepAfterOf(powerSave: true, sec: 180), const Duration(minutes: 5));
    expect(sleepAfterOf(powerSave: true, sec: 0), const Duration(minutes: 1));
    expect(sleepAfterOf(powerSave: false, sec: 180), isNull);
    expect(sleepAfterDefault, const Duration(minutes: 10));
  });

  testWidgets('세이브 v4: 알림 끄기 → SetSetting(notifications, false)', (tester) async {
    final log = await _openSettings(tester, loadFixture('stage37_midgame'));
    await tester.scrollUntilVisible(find.byKey(const Key('settings.notifications')), 100);
    await tester.tap(find.byKey(const Key('settings.notifications')));
    expect(log.sent.map((c) => c.toJson()), [const SetSetting('notifications', false).toJson()]);
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
