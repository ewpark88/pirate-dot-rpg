import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/operator_panel.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// 운영자 패널 2차 (스펙 ui-operator-panel.md ‘2차’). kOperator는 상수라 패널을 직접 띄운다.
Future<CommandLog> _pumpPanel(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(400, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame')),
        commandSinkProvider.overrideWithValue(log),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OperatorPanel()),
      ),
    ),
  );
  await tester.pump();
  return log;
}

Future<void> _tap(WidgetTester tester, String key) async {
  // 패널은 게으른 목록 — 위에 묶음이 늘면(오늘 새 기능) 아래 버튼은 아직 안 지어져 있다. 굴려서 짓는다.
  await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

List<Map<String, Object?>> _json(CommandLog log) => [for (final c in log.sent) c.toJson()];

void main() {
  final tables = GameTables.load();
  final fleet = loadFixture('stage37_midgame').battle!.fleet.map((f) => f.crewId).toList();
  int levelMin(String rarity) => tables.rarities.rarities.firstWhere((r) => r.id == rarity).levelMin;

  testWidgets('기준 10: 출전 선원마다 스킬 버튼, 망타 → OpCastSkill', (tester) async {
    final log = await _pumpPanel(tester);
    for (final id in fleet) {
      expect(find.byKey(Key('op.skill.$id')), findsOneWidget, reason: id);
    }
    await _tap(tester, 'op.skill.manta');
    expect(_json(log), [const OpCastSkill('manta').toJson()]);
  });

  testWidgets('기준 11: 출전 전원 → 전설 첫 레벨 (테이블 levelMin)', (tester) async {
    final log = await _pumpPanel(tester);
    await _tap(tester, 'op.fleetLevel.legend');
    expect(_json(log), [for (final id in fleet) OpSetCrew(id, level: levelMin('legend')).toJson()]);
    expect(levelMin('legend'), 46);
  });

  testWidgets('기준 11: 신화는 61', (tester) async {
    final log = await _pumpPanel(tester);
    await _tap(tester, 'op.fleetLevel.mythic');
    expect(_json(log).first, OpSetCrew(fleet.first, level: 61).toJson());
  });

  testWidgets('기준 12: 상자·순풍·튜토리얼', (tester) async {
    final log = await _pumpPanel(tester);
    await _tap(tester, 'op.chest');
    await _tap(tester, 'op.tailwind');
    await _tap(tester, 'op.tutorial.3');
    await _tap(tester, 'op.tutorial.end');
    expect(_json(log), [
      const OpSpawnChest().toJson(),
      const OpGrantTailwind(Duration(minutes: 30)).toJson(),
      const OpSetTutorial(3).toJson(),
      const OpSetTutorial(null).toJson(),
    ]);
  });
}
