import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_cli/src/fixtures/synthetic_battle.dart';
import 'package:game_cli/src/repo_root.dart';
import 'package:game_core/game_core.dart' hide Command;
import 'package:path/path.dart' as p;

/// `export-events` — 실제 엔진으로 전투를 돌려 렌더 레인용 기록(JSONL)을 만든다. 전투 레인(S1) 담당.
/// `export-events --synthetic` — 손으로 짠 합성 기록 (BattleSystem 구현 전 임시).
class ExportEventsCommand extends Command<int> {
  ExportEventsCommand() {
    argParser
      ..addFlag('synthetic', help: '합성 기록 사용')
      ..addOption('out', defaultsTo: 'fixtures/events/sample_battle.jsonl');
  }

  @override
  String get name => 'export-events';

  @override
  String get description => '렌더 레인용 전투 기록(JSONL) 생성';

  @override
  Future<int> run() async {
    if (!argResults!.flag('synthetic')) {
      return pending('export-events (실제 엔진)', lane: 'battle', milestone: 'M1');
    }
    final out = File(p.join(repoRoot().path, argResults!.option('out')))
      ..createSync(recursive: true)
      ..writeAsStringSync(encodeRecording(syntheticBattle()));
    stdout.writeln('wrote ${p.relative(out.path)}');
    return 0;
  }
}
