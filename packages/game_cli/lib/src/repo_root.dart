import 'dart:io';

import 'package:path/path.dart' as p;

/// LANES.yaml이 있는 폴더 = 저장소 루트. 픽스처·시나리오 경로는 여기 기준.
Directory repoRoot([Directory? from]) {
  var dir = (from ?? Directory.current).absolute;
  while (!File(p.join(dir.path, 'LANES.yaml')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('저장소 루트(LANES.yaml)를 찾지 못했습니다');
    dir = parent;
  }
  return dir;
}

/// 아직 담당 레인이 구현하지 않은 명령. 종료 코드 2.
int pending(String what, {required String lane, required String milestone}) {
  stderr.writeln('$what: 아직 구현되지 않았습니다 — $lane 레인($milestone) 담당, docs/lanes/$lane.md 참고');
  return 2;
}
