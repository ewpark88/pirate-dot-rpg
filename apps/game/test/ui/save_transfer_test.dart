import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/save_transfer.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/settings/save_transfer_section.dart';

import 'ui_harness.dart';

// 설정 '세이브 옮기기' (S5 SaveTransfer · saveImportProvider): 붙여 넣기 → 지금 vs 가져올 진행 → 덮어쓰기 2단 확인 → 가져오기.

Future<void> _open(WidgetTester tester) async {
  showSkinDialog<void>(tester.element(find.byType(HomeScreen)), builder: (_) => const SaveImportDialog()).ignore();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('맞는 코드: 최고 스테이지 37 → 80 · 덮어쓰기 → 한 번 더 확인 → 가져오기 호출', (tester) async {
    GameState? imported;
    final now = loadFixture('stage37_midgame');
    final other = now.copyWith(progress: now.progress.copyWith(bestStage: 80));
    await pumpGame(
      tester,
      now,
      openTab: false,
      overrides: [saveImportProvider.overrideWithValue((s) async => imported = s)],
    );
    await _open(tester);
    await tester.enterText(find.byKey(const Key('save.text')), SaveTransfer.export(other));
    await tester.tap(find.byKey(const Key('save.check')));
    await tester.pump();
    expect(find.text('Best stage ${now.progress.bestStage} → 80'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save.overwrite')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save.sure')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save.sure.yes')));
    await tester.pumpAndSettle();
    expect(imported?.progress.bestStage, 80);
    expect(find.byKey(const Key('save.import')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('깨진 코드: 안내만, 덮어쓰기 버튼 없음', (tester) async {
    await pumpGame(
      tester,
      loadFixture('stage37_midgame'),
      openTab: false,
      overrides: [saveImportProvider.overrideWithValue((s) async {})],
    );
    await _open(tester);
    await tester.enterText(find.byKey(const Key('save.text')), 'PDX1.broken!!');
    await tester.tap(find.byKey(const Key('save.check')));
    await tester.pump();
    expect(find.byKey(const Key('save.bad')), findsOneWidget);
    expect(find.byKey(const Key('save.overwrite')), findsNothing);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [
      ('360', Size(360, 640), 3.0),
      ('384', s24Size, s24Dpr),
      ('411', Size(411, 891), 2.625),
      ('tablet', Size(800, 1280), 2.0),
    ]) {
      testWidgets('가져오기 비교 ko $name', (tester) async {
        final now = loadFixture('stage37_midgame');
        await pumpGame(
          tester,
          now,
          openTab: false,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          overrides: [saveImportProvider.overrideWithValue((s) async {})],
        );
        await _open(tester);
        await tester.enterText(
          find.byKey(const Key('save.text')),
          SaveTransfer.export(now.copyWith(progress: now.progress.copyWith(bestStage: 80))),
        );
        await tester.tap(find.byKey(const Key('save.check')));
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_save_import_$name.png'));
      });
    }
  });
}
