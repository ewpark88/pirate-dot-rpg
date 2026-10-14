import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/file_save_store.dart';
import 'package:pirate_dot/engine_host.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pde_save_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('쓰면 save.json, 두 번째부터 이전 것은 save.bak', () async {
    final store = FileSaveStore(dir);
    expect(await store.read(), isNull);
    await store.write('a');
    await store.write('b');
    expect(await store.read(), 'b');
    expect(await store.readBackup(), 'a');
    expect(File('${dir.path}/save.tmp').existsSync(), isFalse);
  });

  test('save.json이 깨지면 loadSave가 save.bak으로 복구한다', () async {
    final store = FileSaveStore(dir);
    final s = GameState.newGame(playerId: 'p', seed: 1, now: DateTime.utc(2026, 11));
    await store.write(SaveCodec.encode(s));
    await store.write(SaveCodec.encode(s.copyWith(tokens: 5)));
    File('${dir.path}/save.json').writeAsStringSync('{깨짐');
    final loaded = await loadSave(store);
    expect(loaded?.playerId, 'p');
    expect(loaded?.tokens, 0);
  });

  test('전투 1분 → 저장 → 다시 불러오면 진행이 이어진다 (M2 저장·복원)', () async {
    final tables = GameTables.load();
    final start = DateTime.utc(2026, 11);
    final clock = ManualClock(start);
    final store = FileSaveStore(dir);
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 'p', seed: 3, now: start, crews: tables.meta.startingCrews),
      clock: clock,
      store: store,
    );
    for (var i = 0; i < 60 * 20; i++) {
      host.step();
    }
    await host.save();
    final before = host.state;
    await host.dispose();
    final restored = (await loadSave(store))!;
    expect(restored.wallet.gold, before.wallet.gold);
    expect(restored.progress.toJson(), before.progress.toJson());
    expect(restored.wallet.gold.isZero, isFalse);
    final again = EngineHost(tables: tables, initial: restored, clock: clock)..step();
    expect(again.state.progress.stage, before.progress.stage);
    await again.dispose();
  });
}
