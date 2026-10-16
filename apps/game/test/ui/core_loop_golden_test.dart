import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/pixel/pixel_theme.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// 코어 루프 기준 12: 영어 골든 2장 (오프라인 팝업, 설정 화면). 갱신은 사람이 --update-goldens로만.
void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('골든: en_offline_reward', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame'))],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          // 앱과 같은 테마(글꼴·하늘 바탕)로 — 실제 창 모습.
          theme: pixelTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OfflineRewardDialog(
              preview: OfflinePreview(seconds: 7 * 3600 + 25 * 60, gold: BigNum.parse('4.82e6'), cards: 2),
            ),
          ),
        ),
      ),
    );
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_offline_reward.png'));
  });

  testWidgets('골든: en_settings', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    await tester.tap(find.byKey(const Key('hud.settings')));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_settings.png'));
  });
}
