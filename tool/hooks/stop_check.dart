// Stop: “다 했습니다”가 실제 통과를 뜻하게 한다.
// 미커밋 변경이 있으면 (1) 진척 문서 갱신 여부, (2) tool/check.dart 통과를 확인하고, 실패하면 종료를 막는다.
import 'dart:convert';
import 'dart:io';

import 'package:pde_tool/harness.dart';

import 'hook_io.dart';

Future<void> main() async {
  final input = await readHookInput();
  if (input['stop_hook_active'] == true) exit(0); // 이미 한 번 막았다. 무한 반복 방지.

  final root = hookRoot(input);
  final lanes = LaneConfig.load(root);
  final git = gitChanges(root, lanes.mainBranch);
  final uncommitted = Process.runSync('git', ['status', '--porcelain'], workingDirectory: root.path).stdout as String;
  if (uncommitted.trim().isEmpty) exit(0);

  final lane = laneOfBranch(git.branch);
  final progressDoc = lane == null ? 'docs/PROGRESS.md' : 'docs/progress/$lane.md';
  final codeChanged = git.changed.any((f) => !f.startsWith('docs/') && !f.endsWith('.md'));
  if (codeChanged && !git.changed.contains(progressDoc)) {
    block(
      '코드를 바꿨는데 $progressDoc 를 갱신하지 않았습니다.\n'
      '“현재 위치”, 해당 마일스톤 체크박스, 세션 로그(한 일·다음 할 일·남은 문제)를 적고 끝내세요.',
    );
  }

  final r = Process.runSync(
    'dart',
    ['run', 'tool/check.dart'],
    workingDirectory: root.path,
    runInShell: Platform.isWindows,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (r.exitCode != 0) {
    final out = '${r.stdout}${r.stderr}'.trim().split('\n');
    final tail = out.length > 60 ? out.sublist(out.length - 60) : out;
    block('tool/check.dart 실패 — 고치기 전에는 끝낼 수 없습니다:\n${tail.join('\n')}');
  }
}
