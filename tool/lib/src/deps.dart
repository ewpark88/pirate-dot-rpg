import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/src/repo.dart';

/// 패키지별 import 허용 규칙 (docs/ARCHITECTURE.md#의존-규칙).
class DepRule {
  const DepRule({
    required this.dir,
    required this.allowedPackages,
    required this.allowedDartLibs,
    required this.hint,
  });

  /// 루트 기준 검사 폴더.
  final String dir;

  /// `package:<이름>/` 허용 목록. `*`는 모두 허용.
  final Set<String> allowedPackages;

  /// `dart:<이름>` 허용 목록. `*`는 dart:ui를 뺀 모두 허용.
  final Set<String> allowedDartLibs;

  /// 위반 시 덧붙일 고치는 방법.
  final String hint;
}

const _pureDart = {'core', 'async', 'collection', 'convert', 'math', 'typed_data'};

const depRules = [
  DepRule(
    dir: 'packages/game_data/lib',
    allowedPackages: {'game_data'},
    allowedDartLibs: {'core', 'convert'},
    hint: 'game_data는 데이터와 검증만 둡니다. 로직은 packages/game_core로 옮기세요',
  ),
  DepRule(
    dir: 'packages/game_core/lib',
    allowedPackages: {'game_core', 'game_data', 'meta', 'collection', 'crypto'},
    allowedDartLibs: _pureDart,
    hint:
        '렌더링·플랫폼 코드는 apps/game/lib/render/ 또는 adapters/로 옮기고, '
        '외부 세계는 포트(docs/ARCHITECTURE.md#포트)로 주입받으세요',
  ),
  DepRule(
    dir: 'packages/game_cli/lib',
    allowedPackages: {'game_cli', 'game_core', 'game_data', 'args', 'path', 'yaml'},
    allowedDartLibs: {..._pureDart, 'io'},
    hint: 'game_cli는 Flutter 없이 돌아야 합니다',
  ),
  DepRule(
    dir: 'packages/game_cli/bin',
    allowedPackages: {'game_cli', 'game_core', 'game_data', 'args', 'path', 'yaml'},
    allowedDartLibs: {..._pureDart, 'io'},
    hint: 'game_cli는 Flutter 없이 돌아야 합니다',
  ),
  DepRule(
    dir: 'apps/game/lib',
    allowedPackages: {'*'},
    allowedDartLibs: {'*', 'ui'},
    hint: '',
  ),
];

final _importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

/// 모든 Dart 파일의 import를 규칙과 비교한다.
List<Violation> checkDeps(Directory root) {
  final out = <Violation>[];
  for (final rule in depRules) {
    final dir = Directory(p.join(root.path, rule.dir));
    for (final f in filesUnder(dir, extension: '.dart')) {
      final path = rel(root, f.path);
      final src = f.readAsStringSync();
      for (final m in _importRe.allMatches(src)) {
        final uri = m.group(1)!;
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        final msg = _judge(rule, path, uri);
        if (msg != null) out.add(Violation(path, msg, line: line));
      }
    }
  }
  return out;
}

String? _judge(DepRule rule, String path, String uri) {
  if (uri.startsWith('dart:')) {
    final lib = uri.substring(5);
    final ok = rule.allowedDartLibs.contains(lib) || (rule.allowedDartLibs.contains('*') && lib != 'ui');
    return ok ? null : 'imports $uri — ${rule.hint}';
  }
  if (uri.startsWith('package:')) {
    final pkg = uri.substring(8).split('/').first;
    final ownPkg = _ownPackage(rule.dir);
    if (pkg != ownPkg && uri.contains('/src/')) {
      return 'imports $uri — 다른 패키지의 lib/src/는 쓸 수 없습니다. '
          '공개 API(package:$pkg/$pkg.dart 또는 contracts.dart)로 바꾸세요';
    }
    if (!rule.allowedPackages.contains('*') && !rule.allowedPackages.contains(pkg)) {
      return 'imports $uri — ${rule.hint}';
    }
    return path.startsWith('apps/game/lib/') ? _appFolderRule(path, uri) : null;
  }
  // 상대 경로: 앱 안 폴더 규칙만 본다.
  if (path.startsWith('apps/game/lib/')) {
    final target = p.posix.normalize(p.posix.join(p.posix.dirname(path), uri));
    return _appFolderRule(path, 'package:pirate_dot/${target.substring('apps/game/lib/'.length)}');
  }
  return null;
}

String _ownPackage(String dir) => switch (dir) {
  'apps/game/lib' => 'pirate_dot',
  _ => dir.split('/')[1],
};

/// 앱 내부: render/는 ui·adapters를, adapters/는 ui·render를 import하지 않는다.
String? _appFolderRule(String path, String uri) {
  const prefix = 'package:pirate_dot/';
  if (!uri.startsWith(prefix)) return null;
  final target = uri.substring(prefix.length).split('/').first;
  final from = path.substring('apps/game/lib/'.length).split('/').first;
  if (from == 'render' && (target == 'ui' || target == 'adapters')) {
    return 'render/가 $target/를 import합니다 — render는 상태를 읽기만 합니다. '
        '명령이 필요하면 ui/에서 보내세요';
  }
  if (from == 'adapters' && (target == 'ui' || target == 'render')) {
    return 'adapters/가 $target/를 import합니다 — 어댑터는 포트만 구현하고 화면을 몰라야 합니다';
  }
  return null;
}
