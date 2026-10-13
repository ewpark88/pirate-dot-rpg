import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_cli/src/fixtures/sample_states.dart';
import 'package:game_cli/src/fixtures/synthetic_battle.dart';
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

    for (final e in sampleStates(tables).entries) {
      final body = {'schemaVersion': currentSchemaVersion, ...e.value.toJson(includeBattle: true)};
      _write(root, 'fixtures/states/${e.key}.json', '${encoder.convert(body)}\n');
    }
    _write(root, 'fixtures/events/sample_battle.jsonl', encodeRecording(syntheticBattle()));

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
