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

  group('견고화 (스펙 platform-save)', () {
    late List<Duration> waits;
    Future<void> noWait(Duration d) async => waits.add(d);
    setUp(() => waits = []);

    FileSaveStore failing(int failures, {int? osCode}) {
      var n = 0;
      return FileSaveStore(
        dir,
        delay: noWait,
        writer: (f, text) async {
          if (n++ < failures) {
            await f.writeAsString(text.substring(0, text.length ~/ 2)); // 반쯤 쓰다 실패
            throw FileSystemException('쓰기 실패', f.path, osCode == null ? null : OSError('', osCode));
          }
          await f.writeAsString(text, flush: true);
        },
      );
    }

    test('1. 2번 실패 후 3번째 성공 → 저장, failure 없음, 대기 50·200ms', () async {
      final store = failing(2);
      await store.write('a');
      expect(await store.read(), 'a');
      expect(store.failure.value, isNull);
      expect(waits, [const Duration(milliseconds: 50), const Duration(milliseconds: 200)]);
    });

    test('2. 3번 다 실패 → 던지지 않음, io, 기존 save.json 그대로', () async {
      await FileSaveStore(dir).write('old');
      final store = failing(3);
      await store.write('new');
      expect(store.failure.value, SaveFailure.io);
      expect(await store.read(), 'old');
    });

    test('3. 디스크 가득 → 1번만, tmp 지움, diskFull, 기존 파일 그대로', () async {
      final ok = FileSaveStore(dir);
      await ok.write('a');
      await ok.write('b');
      final store = failing(9, osCode: 28);
      await store.write('c');
      expect(waits, isEmpty);
      expect(store.failure.value, SaveFailure.diskFull);
      expect(File('${dir.path}/save.tmp').existsSync(), isFalse);
      expect(await store.read(), 'b');
      expect(await store.readBackup(), 'a');
    });

    test('4. 실패 뒤 성공하면 failure가 지워진다', () async {
      final store = failing(3);
      await store.write('a');
      expect(store.failure.value, SaveFailure.io);
      await store.write('b');
      expect(store.failure.value, isNull);
      expect(await store.read(), 'b');
    });

    test('5. 세 번 쓰면 json·bak·bak2 = 3·2·1번째', () async {
      final store = FileSaveStore(dir);
      for (final t in ['1', '2', '3']) {
        await store.write(t);
      }
      expect(await store.read(), '3');
      expect(File('${dir.path}/save.bak').readAsStringSync(), '2');
      expect(File('${dir.path}/save.bak2').readAsStringSync(), '1');
    });

    test('6. json·bak이 깨지고 bak2가 온전하면 bak2로 복구', () async {
      final store = FileSaveStore(dir);
      final s = GameState.newGame(playerId: 'p', seed: 1, now: DateTime.utc(2026, 11));
      await store.write(SaveCodec.encode(s.copyWith(tokens: 7)));
      await store.write('x');
      await store.write('y');
      File('${dir.path}/save.json').writeAsStringSync('{깨짐');
      File('${dir.path}/save.bak').writeAsStringSync('{깨짐');
      expect((await loadSave(store))?.tokens, 7);
    });

    test('7. bak만 깨지고 bak2가 없으면 기존처럼 SaveCorruptException', () async {
      final store = FileSaveStore(dir);
      await store.write('{깨짐1');
      await store.write('{깨짐2');
      expect(() => loadSave(store), throwsA(isA<SaveCorruptException>()));
    });
  });
}
