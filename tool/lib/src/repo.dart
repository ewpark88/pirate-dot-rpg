import 'dart:io';

import 'package:path/path.dart' as p;

/// 하네스가 찾아낸 규칙 위반 한 건. [message]는 고치는 방법까지 말한다.
class Violation {
  const Violation(this.path, this.message, {this.line});

  final String path;
  final int? line;
  final String message;

  @override
  String toString() => line == null ? '$path — $message' : '$path:$line — $message';
}

/// LANES.yaml이 있는 폴더를 저장소 루트로 본다.
Directory findRepoRoot([Directory? from]) {
  var dir = (from ?? Directory.current).absolute;
  while (true) {
    if (File(p.join(dir.path, 'LANES.yaml')).existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('LANES.yaml을 찾지 못했습니다. 저장소 안에서 실행하세요.');
    }
    dir = parent;
  }
}

/// 루트 기준 상대 경로를 항상 `/` 구분자로 돌려준다.
String rel(Directory root, String path) => p.relative(path, from: root.path).replaceAll(r'\', '/');

/// [dir] 아래의 파일을 재귀로 찾는다. 빌드 산출물·숨김 폴더는 건너뛴다.
Iterable<File> filesUnder(Directory dir, {String? extension}) sync* {
  if (!dir.existsSync()) return;
  for (final e in dir.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final parts = p.split(e.path);
    if (parts.any(_skippedDir.contains)) continue;
    if (extension != null && !e.path.endsWith(extension)) continue;
    yield e;
  }
}

const _skippedDir = {'.dart_tool', 'build', '.git', '.idea', 'Pods'};

/// 생성물은 사람이 고치지 않으므로 크기·문구 검사에서 뺀다.
bool isGenerated(String relPath) =>
    relPath.endsWith('.g.dart') || relPath.contains('/l10n/gen/') || relPath.contains('/l10n/merged/');

/// `//` 주석과 문서 주석 줄을 지운 코드 줄. 줄 번호는 유지한다.
List<String> codeLines(String source) => [
  for (final line in source.split('\n')) line.trimLeft().startsWith('//') ? '' : _stripTrailingComment(line),
];

String _stripTrailingComment(String line) {
  // 문자열 안의 `//`(URL 등)는 남긴다: 따옴표 밖의 첫 `//`만 자른다.
  var quote = '';
  for (var i = 0; i < line.length - 1; i++) {
    final c = line[i];
    if (quote.isEmpty && (c == "'" || c == '"')) {
      quote = c;
    } else if (c == quote) {
      quote = '';
    } else if (quote.isEmpty && c == '/' && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}
