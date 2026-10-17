import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/operator_gate.dart';
import 'package:pirate_dot/operator/operator_panel.dart';
import 'package:pirate_dot/operator/sample_states.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// kOperator는 상수라 테스트에서 켤 수 없다 → 패널을 직접 띄운다.
Future<CommandLog> _pumpPanel(
  WidgetTester tester, {
  Widget home = const Scaffold(body: OperatorPanel()),
  Size size = const Size(400, 800),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame')),
        commandSinkProvider.overrideWithValue(log),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  return log;
}

Future<void> _tap(WidgetTester tester, String key) async {
  // 패널이 길어 아래 묶음은 아직 안 만들어졌을 수 있다 → 보일 때까지 스크롤.
  await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: find.byType(Scrollable).first);
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

List<Map<String, Object?>> _json(CommandLog log) => [for (final c in log.sent) c.toJson()];

void main() {
  test('샘플 상태 4개는 SaveCodec.migrate를 거쳐 모두 읽힌다', () {
    expect(sampleStateNames, ['new_player', 'stage37_midgame', 'boss_fight', 'all_crews_mythic']);
    for (final name in sampleStateNames) {
      expect(loadSampleState(name).playerId, isNotEmpty, reason: name);
    }
  });

  testWidgets('기준 1: 샘플 boss_fight → OpLoadState(stage 5)', (tester) async {
    final log = await _pumpPanel(tester);
    await _tap(tester, 'op.sample.boss_fight');
    expect(log.sent, hasLength(1));
    expect((log.sent.single as OpLoadState).state.progress.stage, 5);
  });

  testWidgets('기준 1-1: 상태가 바뀌면 HUD가 바로 따라온다', (tester) async {
    await pumpGame(tester, loadFixture('new_player'));
    String gold() =>
        tester.widget<Text>(find.descendant(of: find.byKey(const Key('top.gold')), matching: find.byType(Text))).data!;
    final before = gold();
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final boss = loadSampleState('boss_fight');
    container.read(gameStateProvider.notifier).replace(boss);
    await tester.pump();
    expect(gold(), boss.wallet.gold.format());
    expect(gold(), isNot(before));
  });

  testWidgets('기준 2: 배속 ×1 · ×2 · ×4', (tester) async {
    final log = await _pumpPanel(tester);
    for (final s in [1, 2, 4]) {
      await _tap(tester, 'op.speed.$s');
    }
    expect(_json(log), [
      for (final s in [1, 2, 4]) {'type': 'op.speed', 'speed': s},
    ]);
  });

  testWidgets('기준 3·6: 무적·쿨타임 0 스위치', (tester) async {
    final log = await _pumpPanel(tester);
    await _tap(tester, 'op.invincible');
    await _tap(tester, 'op.invincible');
    await _tap(tester, 'op.zeroCooldown');
    expect(_json(log), [
      {'type': 'op.invincible', 'on': true},
      {'type': 'op.invincible', 'on': false},
      const OpZeroCooldown(on: true).toJson(),
    ]);
  });

  testWidgets('기준 4: 보스 소환', (tester) async {
    final log = await _pumpPanel(tester);
    await _tap(tester, 'op.boss');
    expect(log.sent, [isA<OpSpawnBoss>()]);
  });

  testWidgets('기준 5: 스테이지 이동 — 1 이상만', (tester) async {
    final log = await _pumpPanel(tester);
    FilledButton go() => tester.widget<FilledButton>(find.byKey(const Key('op.stage.go')));
    await tester.ensureVisible(find.byKey(const Key('op.stage.input')));
    expect(go().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('op.stage.input')), '0');
    await tester.pump();
    expect(go().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('op.stage.input')), '120');
    await tester.pump();
    await _tap(tester, 'op.stage.go');
    expect(_json(log), [const OpJumpStage(120).toJson()]);
  });

  testWidgets('기준 7: 골드 1e12 · 젬 +1000', (tester) async {
    final log = await _pumpPanel(tester);
    await _tap(tester, 'op.gold.12');
    await _tap(tester, 'op.gems');
    expect(_json(log), [
      OpGrant(gold: BigNum.parse('1e12')).toJson(),
      const OpGrant(gems: 1000).toJson(),
    ]);
  });

  testWidgets('기준 8: 기본 빌드(kOperator 꺼짐)에서는 스테이지 5번 탭으로 열리지 않는다', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    // 스테이지 글자는 캔버스 HUD(논리 x 150, y 6) — 그 자리를 누른다.
    final area = tester.getRect(find.byKey(const Key('battle.area')));
    final stage = area.topLeft + const Offset(160, 8) * (area.width / 320);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(stage);
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OperatorPanel), findsNothing);
  });

  testWidgets('열기 제스처: 5번 누르면 하단 시트, HUD 자리(위 30%)는 가리지 않는다', (tester) async {
    await _pumpPanel(
      tester,
      home: const Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: OperatorTapGate(child: Text('gate')),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('gate'));
    }
    await tester.pump();
    expect(find.byType(OperatorPanel), findsNothing);
    await tester.tap(find.text('gate'));
    await tester.pumpAndSettle();
    expect(find.byType(OperatorPanel), findsOneWidget);
    expect(tester.getTopLeft(find.byType(OperatorPanel)).dy, greaterThanOrEqualTo(800 * 0.3));
  });

  testWidgets('기준 9: 골든 — 운영자 패널 (en)', (tester) async {
    await loadGoldenFonts();
    // 패널 전체가 보이게 세로로 길게.
    await _pumpPanel(tester, size: const Size(400, 1400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_operator_panel.png'));
  });

  testWidgets('오늘 새 기능(6.10): 피버 99% · 브레이크 가득 · 고른 보스 소환 · pelly 전설 출전 · 출항 대기 · 첫 10연 다시', (tester) async {
    final log = await _pumpPanel(tester);
    await _tap(tester, 'op.today.fever');
    expect(log.sent.whereType<OpLoadState>().last.state.progress.fever, closeTo(0.99, 1e-9));
    await _tap(tester, 'op.today.break');
    expect(log.sent.last, isA<OpBossBreak>());
    await _tap(tester, 'op.today.arc');
    expect(log.sent.whereType<OpSetCrew>().last.crewId, 'pelly');
    expect(log.sent.whereType<OpSetFleet>().last.crewIds, ['pelly']);
    await _tap(tester, 'op.today.sail');
    final sail = log.sent.whereType<OpLoadState>().last.state.progress;
    expect((sail.sailHold, sail.rebirths >= 1), (true, true));
    await _tap(tester, 'op.today.firstTen');
    expect(log.sent.whereType<OpLoadState>().last.state.summonsTotal, 0);
    // 보스 고르기 → 소환
    await _tap(tester, 'op.today.bossPick');
    await tester.pumpAndSettle();
    // 특징 많은 보스가 맨 위(42종 — 메뉴는 보이는 것만 짓는다) → 맨 위 항목을 고른다.
    final first = tester.widget<DropdownMenuItem<String>>(find.byType(DropdownMenuItem<String>).last);
    await tester.tap(find.byType(DropdownMenuItem<String>).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('op.today.bossTraits')), findsOneWidget, reason: '고른 보스의 특징 칩');
    await _tap(tester, 'op.today.boss');
    expect((log.sent.last as OpSpawnBoss).bossId, isNotNull);
    expect(first.value, isNotNull);
  });
}
