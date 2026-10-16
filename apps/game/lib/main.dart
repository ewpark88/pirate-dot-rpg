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
import 'package:pirate_dot/adapters/analytics/firebase_sdk.dart';
import 'package:pirate_dot/adapters/analytics/game_event_analytics.dart';
import 'package:pirate_dot/adapters/analytics/sdk_analytics.dart';
import 'package:pirate_dot/adapters/audio/audio_adapter.dart';
import 'package:pirate_dot/adapters/audio/flame_audio_sdk.dart';
import 'package:pirate_dot/adapters/file_save_store.dart';
import 'package:pirate_dot/adapters/notify/local_notifications_sdk.dart';
import 'package:pirate_dot/adapters/notify/offline_full_notifier.dart';
import 'package:pirate_dot/adapters/power/power_channel.dart';
import 'package:pirate_dot/adapters/system_clock.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/operator/crew_lab_group.dart' show operatorBackupProvider;
import 'package:pirate_dot/operator/flags.dart';
import 'package:pirate_dot/proto/proto_screen.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/state/analytics_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/idle.dart';
import 'package:pirate_dot/ui/state/platform_providers.dart';

/// 첫 프레임 전 SDK 초기화가 이보다 오래 걸리면 포기하고 없이 시작한다(Noop·무음) — 스플래시에 갇히지 않게.
const _sdkTimeout = Duration(seconds: 3);

/// 탑다운 전투 시험판 빌드(`--dart-define=PROTO=true`): 게임 대신 시험판 화면만 띄운다. 보통 빌드에선 컴파일 때 빠진다.
const _proto = bool.fromEnvironment('PROTO');

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
  final analytics = await startAnalytics(
    () => initFirebase(collectCrashes: kReleaseMode && !kOperator).timeout(_sdkTimeout),
  );
  step('analytics');
  final audio = await AudioAdapter.load(FlameAudioSdk(), timeout: _sdkTimeout);
  step('audio');
  late final ProviderContainer container;
  final notifier = OfflineFullNotifier(
    sdk: LocalNotificationsSdk(),
    clock: clock,
    dir: supportDir,
    fullAfter: Duration(seconds: tables.meta.offlineMaxSec),
    minAway: Duration(seconds: tables.meta.offlineMinSec),
    dailyMax: tables.meta.notificationsDailyMax,
    enabled: () => container.read(gameStateProvider).settings.notifications,
    lang: () => container.read(gameStateProvider).settings.lang,
  );
  // 생명주기: 광고 화면이 앞에 와서 생기는 pause·resume은 백그라운드로 치지 않는다(광고 뒤 복귀 보상 버그, 2026-10-15).
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
  // Analytics 수집은 꺼진 채 시작, 광고 동의(UMP)가 나면 켠다.
  ads.consent.addListener(() => analytics.setCollection(enabled: ads.consent.value));
  container = ProviderContainer(
    overrides: [
      tablesProvider.overrideWithValue(tables),
      initialGameStateProvider.overrideWithValue(host.state),
      commandSinkProvider.overrideWithValue(host),
      battleFeedProvider.overrideWithValue(host.ticks),
      adsPortProvider.overrideWithValue(ads),
      audioPortProvider.overrideWithValue(audio),
      analyticsPortProvider.overrideWithValue(analytics),
      notifierProvider.overrideWithValue(notifier),
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
    audio.quiet = sfxQuiet(idle: idle, thermal: thermal);
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
  step('runApp');
  // UMP 동의 폼은 화면이 있어야 뜬다 → 첫 프레임 뒤에 광고 시작.
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(ads.start()));
}
