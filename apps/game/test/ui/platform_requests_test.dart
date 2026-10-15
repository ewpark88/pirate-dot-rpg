import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/file_save_store.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/platform_group.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/hud/save_failure_banner.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/platform_providers.dart';

import 'ui_harness.dart';

/// 요청서 platform-operator-test · platform-save-failure.
class _FakeAds implements AdsPort {
  _FakeAds({required this.ready});

  final bool ready;
  final shown = <AdPlacement>[];

  @override
  bool isReady(AdPlacement placement) => ready;

  @override
  Future<AdResult> show(AdPlacement placement) async {
    shown.add(placement);
    return AdResult.rewarded;
  }
}

Future<CommandLog> _pump(
  WidgetTester tester,
  Widget child, {
  AdsPort? ads,
  ValueListenable<SaveFailure?>? failure,
}) async {
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame')),
        commandSinkProvider.overrideWithValue(log),
        if (ads != null) adsPortProvider.overrideWithValue(ads),
        if (failure != null) saveFailureProvider.overrideWithValue(failure),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Column(children: [child])),
      ),
    ),
  );
  await tester.pump();
  return log;
}

void main() {
  testWidgets('운영자 플랫폼: 광고 준비 표시, 보기 → 결과 안내, 보상 명령은 보내지 않음', (tester) async {
    final ads = _FakeAds(ready: true);
    final log = await _pump(tester, const PlatformTestGroup(), ads: ads);
    expect(find.text('Ad: ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('op.adShow')));
    await tester.pump();
    expect(ads.shown, [AdPlacement.chest]);
    expect(find.text('Ad result: rewarded'), findsOneWidget);
    expect(log.sent, isEmpty);
  });

  testWidgets('운영자 플랫폼: 광고 없음·알림 어댑터 없음이면 안 불러옴 표시, 알림 버튼 비활성', (tester) async {
    await _pump(tester, const PlatformTestGroup());
    expect(find.text('Ad: not loaded'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('op.testRing'))).onPressed, isNull);
    // AdMob이 아니면 개인정보 옵션 버튼은 없다
    expect(find.byKey(const Key('op.privacy')), findsNothing);
  });

  testWidgets('저장 실패 띠: 실패 동안만, 종류별 문구, 성공하면 사라짐', (tester) async {
    final failure = ValueNotifier<SaveFailure?>(null);
    await _pump(tester, const SaveFailureBanner(), failure: failure);
    expect(find.byKey(const Key('hud.saveFailure')), findsNothing);

    failure.value = SaveFailure.diskFull;
    await tester.pump();
    expect(find.textContaining('Not enough storage'), findsOneWidget);

    failure.value = SaveFailure.io;
    await tester.pump();
    expect(find.textContaining("Couldn't save"), findsOneWidget);

    failure.value = null;
    await tester.pump();
    expect(find.byKey(const Key('hud.saveFailure')), findsNothing);
  });

  testWidgets('저장 실패 띠: 한국어 360폭 앱 화면에서 넘치지 않는다', (tester) async {
    await pumpGame(
      tester,
      loadFixture('stage37_midgame'),
      locale: const Locale('ko'),
      size: const Size(360, 640),
      overrides: [saveFailureProvider.overrideWithValue(ValueNotifier<SaveFailure?>(SaveFailure.diskFull))],
    );
    expect(find.byKey(const Key('hud.saveFailure')), findsOneWidget);
    expect(find.textContaining('저장 공간이 부족해'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
