import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_cli/src/repo_root.dart';
import 'package:game_cli/src/scenario/runner.dart';
import 'package:path/path.dart' as p;

/// `replay scenarios/boss_fail.yaml` 또는 `replay --all`. 기대 상태와 다르면 종료 코드 1.
class ReplayCommand extends Command<int> {
  ReplayCommand() {
    argParser.addFlag('all', help: 'scenarios/*.yaml 전부');
  }

  @override
  String get name => 'replay';

  @override
  String get description => '시나리오(YAML)를 돌리고 기대 상태와 비교';

  @override
  Future<int> run() async {
    final root = repoRoot();
    final files = argResults!.flag('all')
        ? (Directory(
              p.join(root.path, 'scenarios'),
            ).listSync().whereType<File>().where((f) => f.path.endsWith('.yaml')).toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
        : [for (final a in argResults!.rest) File(p.isAbsolute(a) ? a : p.join(root.path, a))];
    if (files.isEmpty) usageException('시나리오 파일을 주거나 --all을 쓰세요');

    var failed = 0;
    var skipped = 0;
    for (final f in files) {
      final r = runScenario(f, root);
      if (r.skipReason != null) {
        skipped++;
        stdout.writeln('SKIP ${r.name} (${r.skipReason})');
      } else if (r.passed) {
        stdout.writeln('PASS ${r.name}');
      } else {
        failed++;
        stdout.writeln('FAIL ${r.name}');
        for (final m in r.failures) {
          stdout.writeln('  $m');
        }
      }
    }
    stdout.writeln('시나리오 ${files.length}개: 실패 $failed, 건너뜀 $skipped');
    return failed == 0 ? 0 : 1;
  }
}
