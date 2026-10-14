import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/harness.dart';

/// Claude Code 훅 입력(JSON, stdin).
Future<Map<String, dynamic>> readHookInput() async {
  final text = await stdin.transform(const Utf8Decoder(allowMalformed: true)).join();
  return text.trim().isEmpty ? const {} : jsonDecode(text) as Map<String, dynamic>;
}

/// 훅이 검사할 저장소 루트.
///
/// 훅 명령은 `$CLAUDE_PROJECT_DIR`(세션을 연 폴더)에서 돌지만, 레인 세션은 worktree(`D:\Projects\pde-<레인>`)로
/// 옮겨 가서 일할 수 있다. 그래서 고친 파일 → 세션의 현재 폴더(`cwd`) 순서로 실제 저장소를 찾는다.
Directory hookRoot(Map<String, dynamic> input) {
  final toolInput = input['tool_input'] as Map<String, dynamic>? ?? const {};
  final file = (toolInput['file_path'] ?? toolInput['notebook_path']) as String?;
  final cwd = input['cwd'] as String?;
  for (final start in [if (file != null && p.isAbsolute(file)) p.dirname(file), ?cwd]) {
    for (var dir = Directory(start).absolute; ; dir = dir.parent) {
      if (File(p.join(dir.path, 'LANES.yaml')).existsSync()) return dir;
      if (dir.parent.path == dir.path) break;
    }
  }
  return findRepoRoot();
}

/// 수정 대상 파일의 저장소 기준 상대 경로 (없으면 null).
String? editedPath(Map<String, dynamic> input, Directory root) {
  final toolInput = input['tool_input'] as Map<String, dynamic>? ?? const {};
  final path = (toolInput['file_path'] ?? toolInput['notebook_path']) as String?;
  if (path == null) return null;
  return rel(root, p.isAbsolute(path) ? path : p.join(root.path, path));
}

/// exit 2 = Claude에게 stderr를 돌려주고 막는다.
Never block(String message) {
  stderr.writeln(message);
  exit(2);
}
