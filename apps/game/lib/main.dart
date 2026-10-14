import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pirate_dot/adapters/file_save_store.dart';
import 'package:pirate_dot/adapters/system_clock.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tables = GameTables.load();
  const clock = SystemClock();
  final store = FileSaveStore(await getApplicationSupportDirectory());
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
  final container = ProviderContainer(
    overrides: [
      tablesProvider.overrideWithValue(tables),
      initialGameStateProvider.overrideWithValue(host.state),
      commandSinkProvider.overrideWithValue(host),
      battleFeedProvider.overrideWithValue(host.ticks),
    ],
  );
  final controller = container.read(gameStateProvider.notifier);
  host
    ..onState = controller.replace
    ..start();
  // 백그라운드로 가면 저장하고 멈춘다. 돌아오면 다시 돈다 (오프라인 보상은 UI 복귀 팝업이 ClaimOffline으로 받는다).
  AppLifecycleListener(
    onPause: () {
      host.stop();
      unawaited(host.save());
    },
    onResume: host.start,
  );
  runApp(UncontrolledProviderScope(container: container, child: const PirateDotApp()));
}
