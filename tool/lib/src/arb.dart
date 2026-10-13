import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/src/repo.dart';

const arbPartsDir = 'apps/game/lib/l10n/parts';
const arbMergedDir = 'apps/game/lib/l10n/merged';
const languages = ['ko', 'en'];

/// 합친 결과. [violations]가 비어 있어야 [merged]를 쓸 수 있다.
class ArbMergeResult {
  ArbMergeResult(this.merged, this.violations);

  /// 언어 → 합친 ARB.
  final Map<String, Map<String, dynamic>> merged;
  final List<Violation> violations;

  /// 메타데이터(@)를 뺀 문구 키.
  Set<String> get keys => {
    for (final k in merged['en']?.keys ?? const <String>[])
      if (!k.startsWith('@')) k,
  };
}

/// `parts/<레인>.<언어>.arb`를 언어별로 합친다.
/// 규칙: 키는 파일 이름(레인) 접두어로 시작, ko/en 키 집합 일치, 파일 간 중복 금지.
ArbMergeResult mergeArb(Directory root) {
  final dir = Directory(p.join(root.path, arbPartsDir));
  final out = <Violation>[];
  final merged = {
    for (final l in languages) l: <String, dynamic>{'@@locale': l},
  };
  final owner = <String, String>{};
  final parts = <String>{
    for (final f in filesUnder(dir, extension: '.arb')) p.basename(f.path).split('.').first,
  };

  for (final part in parts.toList()..sort()) {
    final byLang = <String, Map<String, dynamic>>{};
    for (final lang in languages) {
      final rp = '$arbPartsDir/$part.$lang.arb';
      final f = File(p.join(root.path, rp));
      if (!f.existsSync()) {
        out.add(Violation(rp, '파일이 없습니다 — ko와 en을 항상 함께 만드세요'));
        continue;
      }
      try {
        byLang[lang] = (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
      } on FormatException catch (e) {
        out.add(Violation(rp, 'JSON 오류: ${e.message}'));
      }
    }
    if (byLang.length != languages.length) continue;

    final keySets = {
      for (final e in byLang.entries) e.key: e.value.keys.where((k) => !k.startsWith('@')).toSet(),
    };
    for (final lang in languages) {
      for (final other in languages.where((l) => l != lang)) {
        for (final k in keySets[other]!.difference(keySets[lang]!)) {
          out.add(Violation('$arbPartsDir/$part.$lang.arb', '$k가 없습니다 ($part.$other.arb에는 있음)'));
        }
      }
    }
    for (final k in keySets['en']!) {
      if (!k.startsWith(part)) {
        out.add(Violation('$arbPartsDir/$part.en.arb', '키 $k는 레인 접두어 "$part"로 시작해야 합니다 — 다른 레인의 문구는 그 레인 파일에 두세요'));
      }
      final prev = owner[k];
      if (prev != null) {
        out.add(Violation('$arbPartsDir/$part.en.arb', '키 $k가 $prev에도 있습니다'));
      }
      owner[k] = part;
    }
    for (final lang in languages) {
      merged[lang]!.addAll(Map.of(byLang[lang]!)..removeWhere((k, _) => k.startsWith('@@')));
    }
  }
  return ArbMergeResult(merged, out);
}

/// 합친 ARB를 merged/에 쓴다.
void writeMergedArb(Directory root, ArbMergeResult result) {
  const encoder = JsonEncoder.withIndent('  ');
  for (final lang in languages) {
    File(p.join(root.path, arbMergedDir, 'app_$lang.arb'))
      ..createSync(recursive: true)
      ..writeAsStringSync('${encoder.convert(result.merged[lang])}\n');
  }
}

final _nameKeyRe = RegExp(r'"(?:nameKey)"\s*:\s*"([^"]+)"');

/// 테이블이 참조하는 l10n 키(nameKey)가 ARB에 있는지 확인한다.
List<Violation> checkTableL10nKeys(Directory root, Set<String> arbKeys) {
  final out = <Violation>[];
  final tables = Directory(p.join(root.path, 'packages/game_data/tables'));
  for (final f in filesUnder(tables, extension: '.json')) {
    for (final m in _nameKeyRe.allMatches(f.readAsStringSync())) {
      final key = m.group(1)!;
      if (!arbKeys.contains(key)) {
        out.add(Violation(rel(root, f.path), 'l10n 키 $key가 ARB에 없습니다 — 담당 레인의 parts/<레인>.ko.arb·.en.arb에 추가하세요'));
      }
    }
  }
  return out;
}
