import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/system_clock.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

void main() {
  final tables = GameTables.load();
  const clock = SystemClock();
  // TODO(platform): SaveStore에서 불러오기 (loadSave). 지금은 매번 새 게임.
  final initial = GameState.newGame(
    playerId: 'local',
    seed: Random().nextInt(1 << 31),
    now: clock.now(),
    crews: tables.meta.startingCrews,
  );
  final host = EngineHost(tables: tables, initial: initial, clock: clock);
  final container = ProviderContainer(
    overrides: [
      tablesProvider.overrideWithValue(tables),
      initialGameStateProvider.overrideWithValue(host.state),
      commandSinkProvider.overrideWithValue(host),
    ],
  );
  final controller = container.read(gameStateProvider.notifier);
  host
    ..onState = controller.replace
    ..start();
  runApp(UncontrolledProviderScope(container: container, child: const PirateDotApp()));
}
