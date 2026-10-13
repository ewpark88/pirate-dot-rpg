import 'dart:convert';
import 'dart:io';

import 'package:game_cli/game_cli.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 레인들이 기다리지 않고 쓰는 픽스처가 계약(contracts.dart)과 맞는지 상시 확인한다.
void main() {
  final root = repoRoot();
  final tables = GameTables.load();
  final crewIds = tables.crews.crews.map((c) => c.id).toSet();

  List<File> filesIn(String dir, String ext) =>
      Directory(p.join(root.path, dir)).listSync().whereType<File>().where((f) => f.path.endsWith(ext)).toList();

  test('fixtures/states/*.json은 GameState로 읽히고 선원 id가 테이블에 있다', () {
    final files = filesIn('fixtures/states', '.json');
    expect(files, isNotEmpty);
    for (final f in files) {
      final state = GameState.fromJson(SaveCodec.migrate(jsonDecode(f.readAsStringSync()) as Json));
      expect(crewIds, containsAll(state.crews.keys), reason: f.path);
      expect(crewIds, containsAll(state.battle?.fleet.map((s) => s.crewId) ?? const <String>[]), reason: f.path);
    }
  });

  test('fixtures/events/*.jsonl은 전투 기록으로 읽힌다', () {
    final files = filesIn('fixtures/events', '.jsonl');
    expect(files, isNotEmpty);
    for (final f in files) {
      final ticks = decodeRecording(f.readAsStringSync());
      expect(ticks, isNotEmpty, reason: f.path);
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i].frame.tick, greaterThan(ticks[i - 1].frame.tick), reason: '${f.path} 틱 순서');
      }
    }
  });

  test('scenarios/*.yaml은 모두 통과하거나 skip 사유가 있다', () {
    for (final f in filesIn('scenarios', '.yaml')) {
      final r = runScenario(f, root, tables: tables);
      expect(r.failures, isEmpty, reason: '${r.name}\n${r.failures.join('\n')}');
    }
  });
}
