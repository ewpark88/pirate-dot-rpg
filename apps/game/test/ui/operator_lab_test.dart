import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/crew_lab_group.dart';
import 'package:pirate_dot/operator/operator_panel.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// 운영자 선원 시험·세이브 백업 (사용자 요청 '모든 캐릭터를 테스트해 보고 싶다', S1 2026-10-16).
class _MemoryStore implements SaveStore {
  String? text;

  @override
  Future<String?> read() async => text;

  @override
  Future<String?> readBackup() async => null;

  @override
  Future<void> write(String json) async => text = json;
}

void main() {
  final tables = GameTables.load();

  Future<CommandLog> pump(WidgetTester tester, {SaveStore? store}) async {
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = CommandLog();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame')),
          commandSinkProvider.overrideWithValue(log),
          if (store != null) operatorBackupProvider.overrideWithValue(store),
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

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('선원 시험: 등급 고르고 선원을 누르면 그 등급 최소 레벨로 보유 + 출전 칸 1', (tester) async {
    final log = await pump(tester);
    await tap(tester, 'op.lab.rarity.mythic');
    await tap(tester, 'op.lab.crew.volt');
    final mythic = tables.rarities.rarities.firstWhere((r) => r.id == 'mythic');
    final sent = [for (final c in log.sent) c.toJson()];
    expect(
      sent,
      containsAllInOrder([OpSetCrew('volt', level: mythic.levelMin).toJson(), const SetFleetSlot(0, 'volt').toJson()]),
    );
  });

  testWidgets('모든 선원 받기: 없는 선원만 일반 최소 레벨로(지금 세이브 유지)', (tester) async {
    final log = await pump(tester);
    await tap(tester, 'op.lab.collectAll');
    final owned = loadFixture('stage37_midgame').crews.keys.toSet();
    final got = {for (final c in log.sent.whereType<OpSetCrew>()) c.crewId};
    expect(got, {
      for (final c in tables.crews.crews)
        if (!owned.contains(c.id)) c.id,
    });
    expect(log.sent.whereType<OpLoadState>(), isEmpty);
  });

  testWidgets('시험 장면: 무리 30 · 기본 파(돌격대 포함) · 보스', (tester) async {
    final log = await pump(tester);
    await tap(tester, 'op.lab.swarm');
    await tap(tester, 'op.lab.wave');
    await tap(tester, 'op.lab.boss');
    expect(
      [for (final c in log.sent) c.toJson()],
      [
        const OpSetWave(count: 30).toJson(),
        const OpSetWave().toJson(),
        const OpSpawnBoss().toJson(),
      ],
    );
  });

  testWidgets('샘플 불러오기 전 내 세이브 백업(한 번만), 내 세이브로 돌아가기 → 백업을 불러오고 비움', (tester) async {
    final store = _MemoryStore();
    final log = await pump(tester, store: store);
    final restore = find.byKey(const Key('op.backup.restore'));
    expect(tester.widget<FilledButton>(restore).onPressed, isNull, reason: '백업 없음');
    await tap(tester, 'op.sample.all_crews_mythic');
    final mine = store.text;
    expect(SaveCodec.decode(mine!).progress.stage, loadFixture('stage37_midgame').progress.stage);
    await tap(tester, 'op.sample.boss_fight');
    expect(store.text, mine, reason: '샘플 위에 샘플을 불러와도 처음 세이브가 남는다');
    await tap(tester, 'op.backup.restore');
    final loaded = log.sent.whereType<OpLoadState>().last;
    expect(loaded.state.progress.stage, loadFixture('stage37_midgame').progress.stage);
    expect(store.text, isEmpty);
    expect(tester.widget<FilledButton>(restore).onPressed, isNull);
  });
}
