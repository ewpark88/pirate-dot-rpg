import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/src/repo.dart';
import 'package:yaml/yaml.dart';

/// LANES.yaml 내용.
class LaneConfig {
  LaneConfig({
    required this.mainBranch,
    required this.lanePaths,
    required this.laneOwnedDocs,
    required this.sessions,
    this.allLanes = const [],
  });

  factory LaneConfig.parse(String yamlText) {
    final y = loadYaml(yamlText) as YamlMap;
    final lanes = (y['lanes'] as YamlMap).cast<String, YamlMap>();
    return LaneConfig(
      mainBranch: y['mainBranch'] as String,
      lanePaths: {
        for (final e in lanes.entries) e.key: (e.value['paths'] as YamlList).cast<String>().toList(),
      },
      laneOwnedDocs: (y['laneOwnedDocs'] as YamlList).cast<String>().toList(),
      sessions: {for (final e in lanes.entries) e.key: e.value['session'] as String},
      allLanes: (y['allLanes'] as YamlList?)?.cast<String>().toList() ?? const [],
    );
  }

  factory LaneConfig.load(Directory root) => LaneConfig.parse(File(p.join(root.path, 'LANES.yaml')).readAsStringSync());

  final String mainBranch;
  final Map<String, List<String>> lanePaths;
  final List<String> laneOwnedDocs;
  final Map<String, String> sessions;

  /// 모든 레인이 바꿀 수 있는 생성물.
  final List<String> allLanes;

  /// 레인이 [path]를 바꿀 수 있는가.
  bool owns(String lane, String path) {
    final patterns = [
      ...lanePaths[lane]!,
      ...allLanes,
      for (final d in laneOwnedDocs) d.replaceAll('{lane}', lane),
    ];
    return patterns.any((pat) => _matches(pat, path));
  }

  /// [path]를 소유한 레인 (없으면 null).
  String? ownerOf(String path) {
    for (final lane in lanePaths.keys) {
      if (lanePaths[lane]!.any((pat) => _matches(pat, path))) return lane;
    }
    return null;
  }
}

bool _matches(String pattern, String path) {
  if (!pattern.contains('*')) return path.startsWith(pattern);
  final re = RegExp('^${RegExp.escape(pattern).replaceAll(r'\*', '[^/]*')}');
  return re.hasMatch(path);
}

/// `lane/<이름>` 또는 `lane/<이름>/...` 브랜치에서 레인 이름을 꺼낸다.
String? laneOfBranch(String branch) {
  final parts = branch.split('/');
  return parts.length >= 2 && parts.first == 'lane' ? parts[1] : null;
}

/// 레인 브랜치의 변경 파일이 소유 경로 안에 있는지 확인한다.
List<Violation> checkLane(LaneConfig cfg, String branch, Iterable<String> changed) {
  final lane = laneOfBranch(branch);
  if (lane == null) return const [];
  if (!cfg.lanePaths.containsKey(lane)) {
    return [Violation('LANES.yaml', '브랜치 $branch의 레인 "$lane"이 LANES.yaml에 없습니다')];
  }
  return [
    for (final path in changed)
      if (!cfg.owns(lane, path))
        Violation(
          path,
          '$lane 레인의 소유 경로 밖입니다${_ownerHint(cfg, path)} — 되돌리고, 꼭 필요하면 '
          'docs/contracts/requests/$lane-<주제>.md에 요청서를 쓰세요',
        ),
  ];
}

String _ownerHint(LaneConfig cfg, String path) {
  final owner = cfg.ownerOf(path);
  return owner == null ? ' (main 전용 공유 경로)' : ' (소유: $owner 레인)';
}

/// git에서 현재 브랜치와 main 대비 변경 파일(커밋·미커밋 모두)을 읽는다.
({String branch, List<String> changed}) gitChanges(Directory root, String mainBranch) {
  String git(List<String> args) {
    final r = Process.runSync('git', args, workingDirectory: root.path);
    // 앞 공백은 지우지 않는다: porcelain 첫 줄 ' M path'의 상태 칸이 잘리면 경로 첫 글자가 사라진다.
    return r.exitCode == 0 ? (r.stdout as String).trimRight() : '';
  }

  final branch = git(['rev-parse', '--abbrev-ref', 'HEAD']);
  final changed = <String>{
    ...git(['diff', '--name-only', '$mainBranch...HEAD']).split('\n'),
    ...parsePorcelain(git(['status', '--porcelain', '--untracked-files=all'])),
  }..remove('');
  return (branch: branch, changed: changed.toList()..sort());
}

/// `git status --porcelain` 출력 → 경로 목록. 각 줄은 상태 2칸 + 공백 + 경로(이름 변경은 `old -> new`).
List<String> parsePorcelain(String out) => [
  for (final l in out.split('\n'))
    if (l.length > 3) l.substring(3).trimRight().split(' -> ').last.replaceAll('"', ''),
];
