// PostToolUse(Edit|Write): 고친 파일을 즉시 정리한다.
// - .dart → dart format + 그 파일 dart analyze. 문제가 있으면 Claude에게 돌려준다.
// - game_data/tables/*.json → tables.g.dart 다시 생성.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/harness.dart';

import 'hook_io.dart';

Future<void> main() async {
  final root = findRepoRoot();
  final path = editedPath(await readHookInput(), root);
  if (path == null || !File(p.join(root.path, path)).existsSync()) exit(0);

  if (path.startsWith('$tablesDir/') && path.endsWith('.json')) {
    File(p.join(root.path, tablesOut)).writeAsStringSync(generateTablesSource(root));
    stdout.writeln('tables.g.dart 다시 생성함');
    exit(0);
  }
  if (!path.endsWith('.dart') || isGenerated(path)) exit(0);

  ProcessResult run(List<String> args) => Process.runSync(
    'dart',
    args,
    workingDirectory: root.path,
    runInShell: Platform.isWindows,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  run(['format', path]);
  final r = run(['analyze', '--fatal-infos', path]);
  if (r.exitCode != 0) {
    block('$path 정적 분석 문제 — 지금 고치세요:\n${r.stdout}${r.stderr}');
  }
}
