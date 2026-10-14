import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_cli/src/fixtures/engine_battle.dart';
import 'package:game_cli/src/fixtures/synthetic_battle.dart';
import 'package:game_cli/src/repo_root.dart';
import 'package:game_core/game_core.dart' hide Command;
import 'package:game_data/game_data.dart';
import 'package:path/path.dart' as p;

/// `export-events` — 실제 엔진으로 전투를 돌려 렌더 레인용 기록(JSONL)과 앱 데모용 Dart 상수를 만든다. 전투 레인(S1) 담당.
/// `export-events --synthetic` — 손으로 짠 합성 기록 (BattleSystem 구현 전의 임시본, 비교용).
class ExportEventsCommand extends Command<int> {
  ExportEventsCommand() {
    argParser
      ..addFlag('synthetic', help: '합성 기록 사용')
      ..addOption('ticks', defaultsTo: '300', help: '기록할 틱 수 (20틱 = 1초)')
      ..addOption('out', defaultsTo: 'fixtures/events/sample_battle.jsonl')
      ..addOption('dart', defaultsTo: demoRecordingPath, help: '앱 데모용 Dart 상수 파일 (빈 값이면 쓰지 않음)');
  }

  @override
  String get name => 'export-events';

  @override
  String get description => '렌더 레인용 전투 기록(JSONL) 생성';

  @override
  Future<int> run() async {
    final root = repoRoot();
    final jsonl = argResults!.flag('synthetic')
        ? encodeRecording(syntheticBattle())
        : encodeRecording(engineBattle(GameTables.load(), ticks: int.parse(argResults!.option('ticks')!)));
    final out = File(p.join(root.path, argResults!.option('out')))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonl);
    stdout.writeln('wrote ${p.relative(out.path)}');
    final dart = argResults!.option('dart') ?? '';
    if (dart.isNotEmpty) {
      final f = File(p.join(root.path, dart))
        ..createSync(recursive: true)
        ..writeAsStringSync(recordingDartSource(jsonl));
      stdout.writeln('wrote ${p.relative(f.path)}');
    }
    return 0;
  }
}

/// 렌더 레인이 앱에서 읽는 데모 기록 (LANES.yaml allLanes).
const demoRecordingPath = 'apps/game/lib/render/demo/sample_battle.g.dart';
