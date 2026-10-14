// 도트 팩의 characters.json에서 crews.json과 선원 이름 ARB를 만든다.
//
//   dart run tool/import_crews.dart <도트 팩의 characters.json 경로>
//
// 도트 팩을 다시 구우면 이 명령을 다시 돌린다. 이름 외의 ARB 키는 보존한다.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/harness.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('사용법: dart run tool/import_crews.dart <characters.json>');
    exit(64);
  }
  final root = findRepoRoot();
  final src = jsonDecode(File(args.single).readAsStringSync()) as Map<String, dynamic>;
  final chars = (src['characters'] as List).cast<Map<String, dynamic>>();
  final crewsFile = File(p.join(root.path, 'packages/game_data/tables/crews.json'));
  final previous = crewsFile.existsSync() ? _previousSkills(crewsFile) : const <String, String>{};

  final crews = [
    for (final c in chars)
      {
        'id': c['id'],
        'num': c['num'],
        'baseRarity': c['rarity'],
        'family': familyAlias[c['family']] ?? c['family'],
        'fx': c['fx'],
        if (previous[c['id']] != null) 'skill': previous[c['id']],
        'portrait': 'crews/${c['id']}.png',
        'nameKey': crewNameKey(c['id'] as String),
      },
  ];
  const encoder = JsonEncoder.withIndent('  ');
  crewsFile.writeAsStringSync('${encoder.convert({'crews': crews})}\n');

  for (final lang in ['ko', 'en']) {
    final file = File(p.join(root.path, 'apps/game/lib/l10n/parts/crew.$lang.arb'));
    final arb = file.existsSync() ? (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>) : <String, dynamic>{};
    for (final c in chars) {
      arb[crewNameKey(c['id'] as String)] = lang == 'ko' ? c['nameKo'] : c['nameEn'];
    }
    file
      ..createSync(recursive: true)
      ..writeAsStringSync('${encoder.convert(arb)}\n');
  }
  stdout.writeln('선원 ${crews.length}명을 가져왔습니다. dart run tool/gen_tables.dart 를 이어서 실행하세요.');
}

/// `octo` → `crewOctoName`. ARB 키는 Dart 식별자여야 하므로 점 대신 camelCase.
String crewNameKey(String id) => 'crew${id[0].toUpperCase()}${id.substring(1)}Name';

/// 도트 팩 계열 이름 → 이 게임의 계열 이름 (설계서 4.3.2: 8번째 계열은 shock).
const familyAlias = {'support': 'shock'};

/// 기존 crews.json의 선원별 `skill` (손으로 정한 값이라 다시 가져와도 보존한다).
Map<String, String> _previousSkills(File f) {
  final crews = (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['crews'] as List;
  return {
    for (final c in crews.cast<Map<String, dynamic>>())
      if (c['skill'] != null) c['id'] as String: c['skill'] as String,
  };
}
