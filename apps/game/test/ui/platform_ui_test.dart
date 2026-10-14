import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/adapters/ads/ads_sdk.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/operator_panel.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/settings/settings_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// 가짜 AdMob SDK: 동의·초기화·로드 성공, 개인정보 옵션 필요 여부와 호출을 기록.
class _FakeSdk implements AdsSdk {
  _FakeSdk({required this.privacyOptionsRequired});

  @override
  final bool privacyOptionsRequired;
  int privacyShown = 0;

  @override
  Future<bool> gatherConsent() async => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> load() async => true;

  @override
  Future<AdShowOutcome> show() async => AdShowOutcome.rewarded;

  @override
  Future<void> showPrivacyOptions() async => privacyShown++;
}

Future<void> _pumpSettings(WidgetTester tester, AdMobAds ads) async {
  // 설정 목록 끝까지 한 화면에 (ListView는 화면 밖 줄을 만들지 않는다).
  tester.view
    ..physicalSize = const Size(400, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame')),
        adsPortProvider.overrideWithValue(ads),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('설정: AdMob이 개인정보 옵션을 요구하면 버튼 → showPrivacyOptions', (tester) async {
    final sdk = _FakeSdk(privacyOptionsRequired: true);
    final ads = AdMobAds(sdk, schedule: (_, _) {});
    await tester.runAsync(ads.start);
    await _pumpSettings(tester, ads);
    await tester.tap(find.byKey(const Key('settings.privacy')));
    await tester.pump();
    expect(sdk.privacyShown, 1);
  });

  testWidgets('설정: 요구하지 않으면(또는 광고 없음) 버튼 없음', (tester) async {
    final ads = AdMobAds(_FakeSdk(privacyOptionsRequired: false), schedule: (_, _) {});
    await tester.runAsync(ads.start);
    await _pumpSettings(tester, ads);
    expect(find.byKey(const Key('settings.privacy')), findsNothing);
  });

  testWidgets('운영자 표식: 패널 루트가 operatorMarker 키를 실제로 쓴다 (배포 빌드 잔존 검사용)', (tester) async {
    expect(operatorMarker, '__OPERATOR_PANEL__');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame'))],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OperatorPanel()),
        ),
      ),
    );
    expect(find.byKey(const ValueKey(operatorMarker)), findsOneWidget);
  });
}
