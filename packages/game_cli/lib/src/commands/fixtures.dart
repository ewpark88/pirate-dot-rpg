import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_cli/src/commands/export_events.dart';
import 'package:game_cli/src/fixtures/engine_battle.dart';
import 'package:game_cli/src/fixtures/sample_states.dart';
import 'package:game_cli/src/repo_root.dart';
import 'package:game_core/game_core.dart' hide Command;
import 'package:game_data/game_data.dart';
import 'package:path/path.dart' as p;

/// `fixtures` — 샘플 상태·합성 전투 기록을 다시 만든다.
/// `fixtures --saves` — 세이브 픽스처(test/fixtures/saves)도 다시 만든다. 사람만 실행한다.
class FixturesCommand extends Command<int> {
  FixturesCommand() {
    argParser.addFlag('saves', help: '세이브 픽스처 갱신 (사람 승인 후에만)');
  }

  @override
  String get name => 'fixtures';

  @override
  String get description => 'fixtures/states, fixtures/events 다시 만들기';

  @override
  Future<int> run() async {
    final root = repoRoot();
    final tables = GameTables.load();
    const encoder = JsonEncoder.withIndent('  ');

    final samples = <String, String>{};
    for (final e in sampleStates(tables).entries) {
      final body = {'schemaVersion': currentSchemaVersion, ...e.value.toJson(includeBattle: true)};
      _write(root, 'fixtures/states/${e.key}.json', '${encoder.convert(body)}\n');
      samples[e.key] = jsonEncode(body);
    }
    _write(root, operatorSamplesPath, operatorSamplesSource(samples));
    final jsonl = encodeRecording(engineBattle(tables));
    _write(root, 'fixtures/events/sample_battle.jsonl', jsonl);
    _write(root, demoRecordingPath, recordingDartSource(jsonl));

    if (argResults!.flag('saves')) {
      final midgame = sampleStates(tables)['stage37_midgame']!;
      _write(
        root,
        'packages/game_core/test/fixtures/saves/v$currentSchemaVersion.json',
        '${SaveCodec.encode(midgame)}\n',
      );
    }
    return 0;
  }

  void _write(Directory root, String rel, String text) {
    File(p.join(root.path, rel))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    stdout.writeln('wrote $rel');
  }
}

/// 운영자 패널의 '샘플 상태 불러오기'가 읽는 생성물 (LANES.yaml allLanes).
const operatorSamplesPath = 'apps/game/lib/operator/sample_states.g.dart';

String operatorSamplesSource(Map<String, String> samples) {
  final b = StringBuffer()
    ..writeln('// 생성물 — 고치지 마세요. `dart run game_cli fixtures`가 fixtures/states/*.json과 함께 씁니다.')
    ..writeln()
    ..writeln('/// 샘플 상태 이름 → 세이브 본문 JSON (schemaVersion 포함).')
    ..writeln('/// `GameState.fromJson(SaveCodec.migrate(jsonDecode(v) as Map<String, dynamic>))`로 읽는다.')
    ..writeln('const Map<String, String> sampleStatesJson = {');
  for (final e in samples.entries) {
    // dart format이 바꾸지 않는 모양: 키 다음 줄에 6칸 들여 쓴 값.
    b
      ..writeln("  '${e.key}':")
      ..writeln("      r'''${e.value}''',");
  }
  b.writeln('};');
  return b.toString();
}
