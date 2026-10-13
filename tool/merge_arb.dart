// apps/game/lib/l10n/parts/<레인>.<언어>.arb → apps/game/lib/l10n/merged/app_<언어>.arb
//
//   dart run tool/merge_arb.dart     (이후 apps/game에서 flutter gen-l10n)
import 'dart:io';

import 'package:pde_tool/harness.dart';

void main() {
  final root = findRepoRoot();
  final result = mergeArb(root);
  final problems = [...result.violations, ...checkTableL10nKeys(root, result.keys)];
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    exit(1);
  }
  writeMergedArb(root, result);
  stdout.writeln('ARB ${result.keys.length}개 키를 합쳤습니다 ($arbMergedDir)');
}
