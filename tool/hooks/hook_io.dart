import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/harness.dart';

/// Claude Code 훅 입력(JSON, stdin).
Future<Map<String, dynamic>> readHookInput() async {
  final text = await stdin.transform(const Utf8Decoder(allowMalformed: true)).join();
  return text.trim().isEmpty ? const {} : jsonDecode(text) as Map<String, dynamic>;
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
