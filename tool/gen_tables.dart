// packages/game_data/tables/*.json → packages/game_data/lib/src/tables.g.dart
//
//   dart run tool/gen_tables.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/harness.dart';

void main() {
  final root = findRepoRoot();
  File(p.join(root.path, tablesOut)).writeAsStringSync(generateTablesSource(root));
  stdout.writeln('$tablesOut 갱신 완료');
}
