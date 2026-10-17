import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pirate_dot/adapters/ad_aware_lifecycle.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/adapters/ads/google_ads_sdk.dart';
import 'package:pirate_dot/adapters/analytics/deferred_analytics.dart';
import 'package:pirate_dot/adapters/analytics/firebase_sdk.dart';
import 'package:pirate_dot/adapters/analytics/game_event_analytics.dart';
import 'package:pirate_dot/adapters/analytics/non_fatal.dart';
import 'package:pirate_dot/adapters/analytics/sdk_analytics.dart';
import 'package:pirate_dot/adapters/audio/audio_adapter.dart';
import 'package:pirate_dot/adapters/audio/flame_audio_sdk.dart';
import 'package:pirate_dot/adapters/file_save_store.dart';
import 'package:pirate_dot/adapters/notify/local_notifications_sdk.dart';
import 'package:pirate_dot/adapters/notify/offline_full_notifier.dart';
import 'package:pirate_dot/adapters/power/power_channel.dart';
import 'package:pirate_dot/adapters/purchase/play_billing_sdk.dart';
import 'package:pirate_dot/adapters/purchase/play_purchases.dart';
import 'package:pirate_dot/adapters/purchase/purchase_bridge.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/adapters/purchase/sim_billing_sdk.dart';
import 'package:pirate_dot/adapters/save_transfer.dart';
import 'package:pirate_dot/adapters/system_clock.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/operator/crew_lab_group.dart' show operatorBackupProvider;
import 'package:pirate_dot/operator/flags.dart';
import 'package:pirate_dot/power_policy.dart';
import 'package:pirate_dot/proto/proto_screen.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/back_to_exit.dart' show exitSaveProvider;
import 'package:pirate_dot/ui/offline/notify_ask.dart' show notifyPermissionProvider;
import 'package:pirate_dot/ui/state/analytics_provider.dart';
import 'package:pirate_dot/ui/state/crash_context.dart' show crashKeyProvider;
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/idle.dart';
import 'package:pirate_dot/ui/state/platform_providers.dart';

/// 첫 프레임 전 SDK 초기화가 이보다 오래 걸리면 포기하고 없이 시작한다(Noop·무음) — 스플래시에 갇히지 않게.
const _sdkTimeout = Duration(seconds: 3);

/// 탑다운 전투 시험판 빌드(`--dart-define=PROTO=true`): 게임 대신 시험판 화면만 띄운다. 보통 빌드에선 컴파일 때 빠진다.
const _proto = bool.fromEnvironment('PROTO');

/// 영수증 패키지 이름 확인(android applicationId). 시험판(.proto 접미사)은 확인하지 않는다.
const String? _packageName = _proto ? null : 'repo.dot.pirate';

Future<void> main() async {
  if (_proto) {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const ProtoApp());
    return;
  }
  // 단계별 시간 (logcat `boot:`) — 같은 프로세스에서 다시 열 때 어디서 멈추는지 바로 보이게 (재실행 멈춤 버그, 2026-10-15).
  final boot = Stopwatch()..start();
  void step(String name) => debugPrint('boot: $name ${boot.elapsedMilliseconds}ms');
  step('start');
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  step('orientation');
  final tables = GameTables.load();
  const clock = SystemClock();
  final supportDir = await getApplicationSupportDirectory();
  step('supportDir');
  final store = FileSaveStore(supportDir);
  // 세이브가 없거나 둘 다 깨졌으면 새 게임 (loadSave가 save.json → save.bak 순서로 시도).
  GameState? saved;
  try {
    saved = await loadSave(store);
  } on SaveCorruptException {
    saved = null;
  }
  step('loadSave');
  final initial =
      saved ??
      GameState.newGame(
        playerId: 'local',
        seed: Random().nextInt(1 << 31),
        now: clock.now(),
        crews: tables.meta.startingCrews,
      );
  final host = EngineHost(tables: tables, initial: initial, clock: clock, store: store);
  // 어댑터 (platform-m4): 실패해도 던지지 않는다 — google-services.json이 없으면 Noop, 음원 목록 실패면 무음.
  // 첫 프레임을 막지 않게(docs/store/cold-start.md): 분석(Firebase)은 runApp 뒤에 붙이고 그 전 호출은 쌓아 둔다,
  // 음원 목록도 기다리지 않는다(오면 그때 배경음). 예전엔 둘 다 최대 3초씩 runApp 앞에서 기다렸다.
  final analytics = DeferredAnalytics();
  final audio = AudioAdapter.later(FlameAudioSdk(), timeout: _sdkTimeout);
  late final ProviderContainer container;
  final notifier = OfflineFullNotifier(
    sdk: LocalNotificationsSdk(),
    clock: clock,
    dir: supportDir,
    fullAfter: Duration(seconds: tables.meta.offlineMaxSec),
    dailyMax: tables.meta.notificationsDailyMax,
    enabled: () => container.read(gameStateProvider).settings.notifications,
    lang: () => container.read(gameStateProvider).settings.lang,
  );
  // 생명주기: 광고 화면이 앞에 와서 생기는 pause·resume은 백그라운드로 치지 않는다(광고 뒤 복귀 보상 버그, 2026-10-15).
  PurchaseBridge? bridge; // 결제 다리 — 아래(광고 뒤)에서 만든다, 복귀 때 복원
  final life = AdAwareLifecycle(
    onBackground: () {
      // 현상금 전투 중이면 후퇴(실패·티켓 반환, 기획 수용 기준 7) — 엔진은 멈춰 있다가 돌아오면 첫 틱에 처리,
      // 그 사이 앱이 꺼지면 다음 실행에서 '중단'으로 같은 처리가 된다. 광고 화면은 AdAwareLifecycle이 거른다.
      if (host.state.bounty?.active != null) host.send(const RetreatBounty());
      unawaited(host.pause());
      unawaited(notifier.onPause());
      audio.pauseBgm(); // 뒤로 가면 배경음도 멈춘다(실기기: 홈 화면에서도 계속 울렸다)
    },
    onForeground: () {
      host.resume();
      unawaited(bridge?.restore()); // 구독 만료·환불 확인
      unawaited(notifier.onResume());
      audio.resumeBgm();
    },
  );
  // 광고가 화면을 덮는 동안: 게임 소리 멈춤(포커스 다툼·겹침 방지) + 오프라인 기준 시각을 지금으로(복귀 창이 안 뜨게).
  final ads = AdMobAds(
    GoogleAdsSdk(),
    onShowStart: () {
      life.adStarted();
      host.markPresent();
      audio.suspend();
    },
    onShowEnd: () {
      host.markPresent();
      life.adEnded();
      audio.unsuspend();
    },
  );
  // 결제(계약 platform-iap — Android만, iOS는 M6): 배포는 Play 결제, 운영자 빌드는 구매 흉내(운영자 패널).
  // 지급 → 저장 → complete 순서는 PurchaseBridge. 광고 제거 권리가 있으면 광고 없이 보상(EntitledAds).
  final sim = kOperator ? SimBillingSdk(prices: {for (final id in tables.iap.products.keys) id: '₩ —'}) : null;
  final shop = Platform.isAndroid
      ? PlayPurchases(sim ?? PlayBillingSdk(), catalog: purchaseCatalog(tables), packageName: _packageName)
      : null;
  bridge = shop == null
      ? null
      : (PurchaseBridge(
          shop: shop,
          tables: tables,
          send: host.send,
          state: () => host.state,
          ticks: host.ticks,
          save: host.save,
        )..start());
  final paidAds = EntitledAds(ads, noAds: () => entitlementActive(host.state, 'noAds', clock.now()));
  // Analytics 수집은 꺼진 채 시작, 광고 동의(UMP)가 나면 켠다.
  ads.consent.addListener(() => analytics.setCollection(enabled: ads.consent.value));
  container = ProviderContainer(
    overrides: [
      tablesProvider.overrideWithValue(tables),
      initialGameStateProvider.overrideWithValue(host.state),
      commandSinkProvider.overrideWithValue(host),
      battleFeedProvider.overrideWithValue(host.ticks),
      adsPortProvider.overrideWithValue(paidAds),
      if (shop != null) purchaseServiceProvider.overrideWithValue(shop),
      purchaseBridgeProvider.overrideWithValue(bridge),
      simBillingProvider.overrideWithValue(sim),
      saveImportProvider.overrideWithValue(host.replace), // 설정 '세이브 옮기기'(코드 가져오기)
      // 뒤로 두 번 종료 직전 저장(S4 back_to_exit) — 느린 기기에서 종료가 멈춰 보이지 않게 1초까지만 기다린다(crash-anr.md 3절)
      crashKeyProvider.overrideWithValue(analytics.setCrashKey), // 충돌 보고서 맥락 키(S4 CrashContextGate)
      exitSaveProvider.overrideWithValue(() => host.save().timeout(const Duration(seconds: 1), onTimeout: () {})),
      audioPortProvider.overrideWithValue(audio),
      analyticsPortProvider.overrideWithValue(analytics),
      notifierProvider.overrideWithValue(notifier),
      notifyPermissionProvider.overrideWithValue(notifier.requestPermission), // 알림 권한은 화면이 좋은 때 묻는다(S4 notify_ask)
      saveFailureProvider.overrideWithValue(store.failure),
      // 운영자 빌드만: 샘플 불러오기 전 내 세이브 백업(지원 폴더/operator_backup) — 배포 빌드에선 상수로 빠진다
      if (kOperator)
        operatorBackupProvider.overrideWithValue(FileSaveStore(Directory('${supportDir.path}/operator_backup'))),
    ],
  );
  final controller = container.read(gameStateProvider.notifier);
  // 분석: 엔진 이벤트 중 필요한 것만(현상금 bounty_start/clear/fail/sweep).
  host.ticks.listen((t) => logGameEvents(analytics, t.events));
  host
    ..onState = controller.replace
    ..start();
  unawaited(bridge?.restore()); // 소유 권리 맞추기 + 끝나지 않은 구매(앱이 complete 전에 죽음) 받기
  // 설정에서 끄면 남은 예약을 바로 취소한다.
  container.listen(
    gameStateProvider.select((s) => s.settings.notifications),
    (_, on) => unawaited(notifier.onSettingChanged(enabled: on)),
  );
  // 발열 대책(실기기 S24 2026-10-17): 주사율 60Hz(방치·절전·발열 보통 이상 30Hz), 방치·발열 심함이면 효과음 끔, 발열 단계 공유.
  final power = PowerChannel();
  void applyPower() {
    final idle = container.read(idleLevelProvider);
    final thermal = container.read(thermalLevelProvider);
    unawaited(power.setFrameRate(targetFrameRate(idle: idle, thermal: thermal)));
    audio
      ..quiet = sfxQuiet(idle: idle, thermal: thermal)
      ..maxTotal = sfxMaxTotal(thermal: thermal, normal: AudioAdapter.maxTotalSfx);
  }

  container
    ..listen(idleLevelProvider, (_, _) => applyPower())
    ..listen(thermalLevelProvider, (_, _) => applyPower());
  power.changes.listen((t) => container.read(thermalLevelProvider.notifier).set(t));
  unawaited(power.thermal().then((t) => container.read(thermalLevelProvider.notifier).set(t)));
  unawaited(power.keepScreenOn().then((on) => debugPrint('power: keepScreenOn=$on')));
  applyPower();
  // 백그라운드로 가면 저장하고 멈춘다. 돌아오면 다시 돈다 (오프라인 보상은 UI 복귀 팝업이 ClaimOffline으로 받는다).
  // 엔진이 떨어지면(액티비티 종료) 타이머·배경음을 멈춘다 — 떨어진 엔진에 플랫폼 메시지를 계속 보내지 않게.
  AppLifecycleListener(
    onPause: life.pause,
    onResume: life.resume,
    onDetach: () {
      unawaited(host.pause());
      audio.stopBgm();
    },
  );
  runApp(UncontrolledProviderScope(container: container, child: const PirateDotApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) => step('firstFrame')); // 콜드 스타트 목표 2초(cold-start.md)
  unawaited(
    startAnalytics(() async {
      final sdk = await initFirebase(collectCrashes: kReleaseMode && !kOperator).timeout(_sdkTimeout);
      // 비치명 오류(광고·전원·알림·세이브·오디오가 잡은 예외)도 Crashlytics로 — 사유마다 실행당 1회(crash-anr.md 2절)
      nonFatalSink = (e, s, reason) => unawaited(sdk.recordNonFatal(e, s, reason: reason));
      return sdk;
    }).then((a) {
      analytics.attach(a);
      step('analytics');
    }),
  );
  step('runApp');
  // UMP 동의 폼은 화면이 있어야 뜬다 → 첫 프레임 뒤에 광고 시작.
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(ads.start()));
}
