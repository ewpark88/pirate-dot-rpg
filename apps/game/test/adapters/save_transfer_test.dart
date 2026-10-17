import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/save_transfer.dart';
import 'package:pirate_dot/engine_host.dart';

/// 세이브 옮기기 코드(기기 교체 — 사용자 S1 2026-10-18).
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11, 2, 3);
  GameState fixture() => GameState.fromJson(
    jsonDecode(File('../../fixtures/states/all_crews_mythic.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('내보내기 → 가져오기 왕복: 같은 세이브(체크섬 그대로), 코드는 원문보다 짧다', () {
    final s = fixture();
    final code = SaveTransfer.export(s);
    expect(code, startsWith(SaveTransfer.prefix));
    expect(code.length, lessThan(SaveCodec.encode(s).length));
    final back = SaveTransfer.import(code);
    expect(jsonEncode(back.toJson()), jsonEncode(SaveCodec.decode(SaveCodec.encode(s)).toJson()));
  });

  test('메신저가 줄을 나누거나 공백을 넣어도 가져온다', () {
    final code = SaveTransfer.export(fixture());
    final wrapped = [
      for (var i = 0; i < code.length; i += 40) code.substring(i, (i + 40).clamp(0, code.length)),
    ].join('\n ');
    expect(SaveTransfer.import(wrapped).playerId, fixture().playerId);
  });

  test('다른 글·깨진 코드·한 글자 바뀐 코드는 SaveCorruptException', () {
    expect(() => SaveTransfer.import('hello'), throwsA(isA<SaveCorruptException>()));
    expect(() => SaveTransfer.import('${SaveTransfer.prefix}!!!'), throwsA(isA<SaveCorruptException>()));
    // 압축 전 세이브 JSON의 숫자 하나를 바꿔 다시 감싸면 체크섬이 맞지 않는다.
    final json = SaveCodec.encode(fixture()).replaceFirst('"tokens":', '"tokens":9');
    final forged = SaveTransfer.prefix + base64Url.encode(gzip.encode(utf8.encode(json)));
    expect(() => SaveTransfer.import(forged), throwsA(isA<SaveCorruptException>()));
  });

  test('EngineHost.replace: 가져온 세이브로 엔진을 바꾸고 바로 저장(savedAt = 지금)', () async {
    final written = <String>[];
    final host = EngineHost(
      tables: t,
      initial: GameState.newGame(playerId: 'new', seed: 1, now: start),
      clock: ManualClock(start),
      store: _MemStore(written),
    );
    final imported = SaveTransfer.import(SaveTransfer.export(fixture()));
    await host.replace(imported);
    expect(host.state.playerId, imported.playerId);
    expect(host.state.savedAt, start);
    expect(written, isNotEmpty);
    expect(SaveCodec.decode(written.last).playerId, imported.playerId);
  });
}

class _MemStore implements SaveStore {
  _MemStore(this.written);

  final List<String> written;

  @override
  Future<String?> read() async => written.lastOrNull;

  @override
  Future<String?> readBackup() async => null;

  @override
  Future<void> write(String json) async => written.add(json);
}
