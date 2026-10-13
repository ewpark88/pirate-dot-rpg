import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/src/repo.dart';

const maxLines = 300;

/// 금지 패턴 검사 모음 (설계서 6.3).
List<Violation> checkRules(Directory root) => [
  ...checkNondeterminism(root),
  ...checkBalanceLiterals(root),
  ...checkHardcodedText(root),
  ...checkFileSize(root),
  ...checkLicenses(root),
  ...checkOperatorGuard(root),
];

final _nondeterministic = RegExp(r'DateTime\.now\(|\bRandom\(|\bStopwatch\(');

/// game_core는 시계·난수를 직접 쓰지 않는다.
List<Violation> checkNondeterminism(Directory root) => [
  for (final f in filesUnder(Directory(p.join(root.path, 'packages/game_core/lib')), extension: '.dart'))
    ..._grep(root, f, _nondeterministic, 'Clock / Rng 포트를 주입받으세요 (docs/ARCHITECTURE.md#포트). 직접 호출은 결정론을 깹니다'),
];

/// 0·1 외 숫자. 식별자 일부(`x2`), 소수점 뒤, 16진수는 제외.
final _numberLiteral = RegExp(r'(?<![\w.$])(\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)(?![\w.])');

/// 전투·경제 로직의 수치는 game_data 테이블에서 읽는다.
List<Violation> checkBalanceLiterals(Directory root) {
  final out = <Violation>[];
  for (final sub in ['battle', 'economy']) {
    final dir = Directory(p.join(root.path, 'packages/game_core/lib/src', sub));
    for (final f in filesUnder(dir, extension: '.dart')) {
      final lines = codeLines(_stripStrings(f.readAsStringSync()));
      for (var i = 0; i < lines.length; i++) {
        for (final m in _numberLiteral.allMatches(lines[i])) {
          final n = num.parse(m.group(1)!);
          if (n == 0 || n == 1) continue;
          out.add(
            Violation(
              rel(root, f.path),
              '숫자 리터럴 ${m.group(1)} — 수치는 packages/game_data/tables/*.json에 추가하고 테이블에서 읽으세요',
              line: i + 1,
            ),
          );
        }
      }
    }
  }
  return out;
}

final _textLiteral = RegExp(r'''\bText\(\s*['"]''');
final _hangul = RegExp('[가-힣]');

/// 화면 문구는 ARB에만. 앱 코드의 `Text('…')`와 한글 리터럴 금지.
List<Violation> checkHardcodedText(Directory root) {
  final out = <Violation>[];
  for (final f in filesUnder(Directory(p.join(root.path, 'apps/game/lib')), extension: '.dart')) {
    final path = rel(root, f.path);
    if (isGenerated(path)) continue;
    final lines = codeLines(f.readAsStringSync());
    for (var i = 0; i < lines.length; i++) {
      if (_textLiteral.hasMatch(lines[i]) || _hangul.hasMatch(lines[i])) {
        out.add(
          Violation(
            path,
            '하드코딩 문구 — apps/game/lib/l10n/parts/<레인>.ko.arb와 .en.arb에 키를 추가하고 '
            'AppLocalizations로 읽으세요',
            line: i + 1,
          ),
        );
      }
    }
  }
  return out;
}

/// 300줄 초과 파일은 책임별로 나눈다.
List<Violation> checkFileSize(Directory root) {
  final out = <Violation>[];
  for (final dir in ['packages', 'apps/game/lib', 'tool']) {
    for (final f in filesUnder(Directory(p.join(root.path, dir)), extension: '.dart')) {
      final path = rel(root, f.path);
      if (isGenerated(path) || path.contains('/test/')) continue;
      final n = f.readAsLinesSync().length;
      if (n > maxLines) {
        out.add(Violation(path, '$n줄 — $maxLines줄 이하가 되도록 책임별로 나누세요'));
      }
    }
  }
  return out;
}

const allowedLicenses = {'CC0-1.0', 'OFL-1.1', 'MIT', 'OWN'};

/// apps/game/assets의 모든 파일은 LICENSES.json에 출처·라이선스가 있어야 한다.
List<Violation> checkLicenses(Directory root) {
  final assets = Directory(p.join(root.path, 'apps/game/assets'));
  final licFile = File(p.join(assets.path, 'LICENSES.json'));
  const licPath = 'apps/game/assets/LICENSES.json';
  if (!licFile.existsSync()) return [const Violation(licPath, '파일이 없습니다 — 빈 {"files": {}}로 만드세요')];
  final files = ((jsonDecode(licFile.readAsStringSync()) as Map)['files'] as Map).cast<String, dynamic>();
  final out = <Violation>[];
  for (final f in filesUnder(assets)) {
    final key = rel(assets, f.path);
    if (key == 'LICENSES.json' || key.endsWith('.gitkeep')) continue;
    final entry = files[key] as Map?;
    if (entry == null) {
      out.add(Violation('apps/game/assets/$key', 'LICENSES.json에 등록되지 않은 에셋 — "files"에 {"source", "license"}를 추가하세요'));
    } else if (!allowedLicenses.contains(entry['license'])) {
      out.add(
        Violation(
          'apps/game/assets/$key',
          '라이선스 ${entry['license']}는 쓸 수 없습니다 — ${allowedLicenses.join('·')} 중 하나만 허용',
        ),
      );
    }
  }
  return out;
}

/// 운영자 코드(lib/operator/)는 kOperator 가드 뒤에서만 부른다. 스토어 빌드에서 트리 셰이킹되도록.
List<Violation> checkOperatorGuard(Directory root) {
  final out = <Violation>[];
  final lib = Directory(p.join(root.path, 'apps/game/lib'));
  for (final f in filesUnder(lib, extension: '.dart')) {
    final path = rel(root, f.path);
    if (path.startsWith('apps/game/lib/operator/')) continue;
    final src = f.readAsStringSync();
    final importsOperator = RegExp(r'''import\s+['"][^'"]*operator/(?!flags\.dart)''').hasMatch(src);
    if (importsOperator && !src.contains('if (kOperator')) {
      out.add(Violation(path, '운영자 코드를 가드 없이 씁니다 — `if (kOperator) { ... }` 안에서만 부르세요 (docs/GAME_DESIGN.md 6.10)'));
    }
  }
  return out;
}

List<Violation> _grep(Directory root, File f, RegExp re, String msg) {
  final lines = codeLines(f.readAsStringSync());
  return [
    for (var i = 0; i < lines.length; i++)
      if (re.hasMatch(lines[i])) Violation(rel(root, f.path), msg, line: i + 1),
  ];
}

/// 문자열 리터럴 내용을 비운다(숫자 검사에서 문자열 속 숫자 제외). 줄 수는 유지.
String _stripStrings(String src) => src.replaceAll(_stringLiteral, "''");

final _stringLiteral = RegExp(
  r"'(?:[^'\\\n]|\\.)*'"
  '|'
  r'"(?:[^"\\\n]|\\.)*"',
);
