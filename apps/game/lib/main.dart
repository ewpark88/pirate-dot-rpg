import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/adapters/ads/google_ads_sdk.dart';
import 'package:pirate_dot/adapters/analytics/firebase_sdk.dart';
import 'package:pirate_dot/adapters/analytics/sdk_analytics.dart';
import 'package:pirate_dot/adapters/audio/audio_adapter.dart';
import 'package:pirate_dot/adapters/audio/flame_audio_sdk.dart';
import 'package:pirate_dot/adapters/file_save_store.dart';
import 'package:pirate_dot/adapters/notify/local_notifications_sdk.dart';
import 'package:pirate_dot/adapters/notify/offline_full_notifier.dart';
import 'package:pirate_dot/adapters/system_clock.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/operator/flags.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/state/analytics_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tables = GameTables.load();
  const clock = SystemClock();
  final supportDir = await getApplicationSupportDirectory();
  final store = FileSaveStore(supportDir);
  // 세이브가 없거나 둘 다 깨졌으면 새 게임 (loadSave가 save.json → save.bak 순서로 시도).
  GameState? saved;
  try {
    saved = await loadSave(store);
  } on SaveCorruptException {
    saved = null;
  }
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
  final analytics = await startAnalytics(() => initFirebase(collectCrashes: kReleaseMode && !kOperator));
  final audio = await AudioAdapter.load(FlameAudioSdk());
  final ads = AdMobAds(GoogleAdsSdk());
  // Analytics 수집은 꺼진 채 시작, 광고 동의(UMP)가 나면 켠다.
  ads.consent.addListener(() => analytics.setCollection(enabled: ads.consent.value));
  final container = ProviderContainer(
    overrides: [
      tablesProvider.overrideWithValue(tables),
      initialGameStateProvider.overrideWithValue(host.state),
      commandSinkProvider.overrideWithValue(host),
      battleFeedProvider.overrideWithValue(host.ticks),
      adsPortProvider.overrideWithValue(ads),
      audioPortProvider.overrideWithValue(audio),
      analyticsPortProvider.overrideWithValue(analytics),
    ],
  );
  final controller = container.read(gameStateProvider.notifier);
  host
    ..onState = controller.replace
    ..start();
  final notifier = OfflineFullNotifier(
    sdk: LocalNotificationsSdk(),
    clock: clock,
    dir: supportDir,
    fullAfter: Duration(seconds: tables.meta.offlineMaxSec),
    minAway: Duration(seconds: tables.meta.offlineMinSec),
    dailyMax: tables.meta.notificationsDailyMax,
    enabled: () => true, // TODO(platform): settings.notifications (세이브 계약 반영 뒤)
    lang: () => container.read(gameStateProvider).settings.lang,
  );
  // 백그라운드로 가면 저장하고 멈춘다. 돌아오면 다시 돈다 (오프라인 보상은 UI 복귀 팝업이 ClaimOffline으로 받는다).
  AppLifecycleListener(
    onPause: () {
      unawaited(host.pause());
      unawaited(notifier.onPause());
    },
    onResume: () {
      host.resume();
      unawaited(notifier.onResume());
    },
  );
  runApp(UncontrolledProviderScope(container: container, child: const PirateDotApp()));
  // UMP 동의 폼은 화면이 있어야 뜬다 → 첫 프레임 뒤에 광고 시작.
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(ads.start()));
}
