import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pde_tool/harness.dart';
import 'package:test/test.dart';

/// M0 완료 조건: 일부러 규칙을 어긴 코드가 검사에서 실패하는지 확인한다.
/// 각 테스트는 임시 폴더에 작은 가짜 저장소를 만들고 검사 함수를 돌린다.
void main() {
  final realRoot = findRepoRoot();
  late Directory root;

  void put(String rel, String content) => File(p.join(root.path, rel))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  setUp(() {
    root = Directory.systemTemp.createTempSync('harness_');
    File(p.join(realRoot.path, 'LANES.yaml')).copySync(p.join(root.path, 'LANES.yaml'));
    put('apps/game/assets/LICENSES.json', '{"files": {}}');
  });
  tearDown(() => root.deleteSync(recursive: true));

  Matcher violation(String path, String hint) => contains(
    isA<Violation>().having((v) => v.path, 'path', path).having((v) => v.message, 'message', contains(hint)),
  );

  group('의존 방향', () {
    test('game_core가 Flutter를 import하면 실패하고 옮길 곳을 알려준다', () {
      put('packages/game_core/lib/src/battle/x.dart', "import 'package:flutter/material.dart';");
      expect(checkDeps(root), violation('packages/game_core/lib/src/battle/x.dart', 'apps/game/lib/render/'));
    });

    test('game_core의 dart:io 금지, dart:math 허용', () {
      put('packages/game_core/lib/src/a.dart', "import 'dart:io';\nimport 'dart:math';");
      final v = checkDeps(root);
      expect(v, hasLength(1));
      expect(v.single.message, contains('dart:io'));
    });

    test('game_data는 dart:convert만', () {
      put('packages/game_data/lib/x.dart', "import 'package:collection/collection.dart';");
      expect(checkDeps(root), isNotEmpty);
    });

    test('앱이 다른 패키지의 lib/src/를 쓰면 실패', () {
      put('apps/game/lib/ui/x.dart', "import 'package:game_core/src/engine/core_engine.dart';");
      expect(checkDeps(root), violation('apps/game/lib/ui/x.dart', '공개 API'));
    });

    test('render → ui, adapters → render 금지 (상대 경로 포함)', () {
      put('apps/game/lib/render/a.dart', "import '../ui/home.dart';");
      put('apps/game/lib/adapters/b.dart', "import 'package:pirate_dot/render/a.dart';");
      final v = checkDeps(root);
      expect(v, violation('apps/game/lib/render/a.dart', 'render는 상태를 읽기만'));
      expect(v, violation('apps/game/lib/adapters/b.dart', '포트만 구현'));
    });
  });

  group('금지 패턴', () {
    test('코어의 DateTime.now / Random( / Stopwatch(', () {
      put('packages/game_core/lib/src/economy/a.dart', 'final t = DateTime.now();\n// DateTime.now() 주석은 괜찮다');
      put('packages/game_core/lib/src/b.dart', 'final r = Random(3);');
      final v = checkNondeterminism(root);
      expect(v, hasLength(2));
      expect(v.first.message, contains('Clock / Rng 포트'));
    });

    test('전투·경제 로직의 0·1 외 숫자 리터럴', () {
      put('packages/game_core/lib/src/economy/cost.dart', "final c = 10 * 1.15;\nfinal ok = 0 + 1;\nconst s = 'x25';");
      final v = checkBalanceLiterals(root);
      expect(v.map((e) => e.message), [contains('10'), contains('1.15')]);
      expect(v.first.message, contains('tables'));
    });

    test('앱의 하드코딩 문구 (Text 리터럴, 한글)', () {
      put('apps/game/lib/ui/a.dart', "final a = Text('Hello');\nfinal b = '보물';\n// 주석의 한글은 괜찮다");
      expect(checkHardcodedText(root), hasLength(2));
    });

    test('생성된 l10n 파일의 한글은 검사하지 않는다', () {
      put('apps/game/lib/l10n/gen/app_localizations_ko.dart', "String get t => '해적';");
      expect(checkHardcodedText(root), isEmpty);
    });

    test('300줄 초과 파일', () {
      put('packages/game_core/lib/src/big.dart', List.filled(maxLines + 1, '// x').join('\n'));
      expect(checkFileSize(root), violation('packages/game_core/lib/src/big.dart', '책임별로 나누세요'));
    });

    test('등록 안 된 에셋, 허용 안 된 라이선스', () {
      put('apps/game/assets/a.png', '');
      put('apps/game/assets/b.ogg', '');
      put('apps/game/assets/LICENSES.json', '{"files": {"b.ogg": {"source": "x", "license": "CC-BY-SA-4.0"}}}');
      final v = checkLicenses(root);
      expect(v, violation('apps/game/assets/a.png', '등록되지 않은'));
      expect(v, violation('apps/game/assets/b.ogg', '쓸 수 없습니다'));
    });

    test('운영자 코드는 kOperator 가드 안에서만', () {
      put('apps/game/lib/ui/a.dart', "import 'package:pirate_dot/operator/operator_panel.dart';");
      put('apps/game/lib/ui/b.dart', "import '../operator/operator_panel.dart';\nif (kOperator) {}");
      put('apps/game/lib/ui/c.dart', "import '../operator/flags.dart';");
      expect(checkOperatorGuard(root).map((v) => v.path), ['apps/game/lib/ui/a.dart']);
    });
  });

  group('다국어', () {
    test('ko만 있는 ARB는 실패', () {
      put('apps/game/lib/l10n/parts/ui.ko.arb', '{"uiA": "가"}');
      expect(mergeArb(root).violations, violation('apps/game/lib/l10n/parts/ui.en.arb', 'ko와 en을 항상 함께'));
    });

    test('ko/en 키 불일치, 레인 접두어 위반, 파일 간 중복', () {
      put('apps/game/lib/l10n/parts/ui.ko.arb', '{"uiA": "가", "uiB": "나", "battleX": "다"}');
      put('apps/game/lib/l10n/parts/ui.en.arb', '{"uiA": "a", "battleX": "x"}');
      put('apps/game/lib/l10n/parts/battle.ko.arb', '{"battleX": "다"}');
      put('apps/game/lib/l10n/parts/battle.en.arb', '{"battleX": "x"}');
      final v = mergeArb(root).violations;
      expect(v, violation('apps/game/lib/l10n/parts/ui.en.arb', 'uiB가 없습니다'));
      expect(v, violation('apps/game/lib/l10n/parts/ui.en.arb', '접두어 "ui"'));
      expect(v, violation('apps/game/lib/l10n/parts/ui.en.arb', 'battle에도 있습니다'));
    });

    test('ARB 조각을 고치고 merge_arb를 안 돌리면 실패', () {
      put('apps/game/lib/l10n/parts/ui.ko.arb', '{"uiA": "가"}');
      put('apps/game/lib/l10n/parts/ui.en.arb', '{"uiA": "a"}');
      writeMergedArb(root, mergeArb(root));
      expect(checkMergedArbFresh(root, mergeArb(root)), isEmpty);
      put('apps/game/lib/l10n/parts/ui.en.arb', '{"uiA": "b"}');
      expect(checkMergedArbFresh(root, mergeArb(root)).single.path, endsWith('app_en.arb'));
    });

    test('테이블의 nameKey가 ARB에 없으면 실패', () {
      put('packages/game_data/tables/x.json', '{"nameKey": "shipPartLaser"}');
      expect(
        checkTableL10nKeys(root, {'shipPartCannon'}),
        violation('packages/game_data/tables/x.json', 'shipPartLaser'),
      );
    });
  });

  test('테이블 JSON을 고치고 gen_tables를 안 돌리면 실패', () {
    put('packages/game_data/tables/a.json', '{"v": 1}');
    put(tablesOut, generateTablesSource(root));
    expect(checkTablesFresh(root), isEmpty);
    put('packages/game_data/tables/a.json', '{"v": 2}');
    expect(checkTablesFresh(root).single.message, contains('gen_tables'));
  });

  group('레인 소유권', () {
    final cfg = LaneConfig.load(realRoot);

    test('render 레인이 ui 경로를 고치면 실패하고 소유 레인을 알려준다', () {
      final v = checkLane(cfg, 'lane/render', ['apps/game/lib/render/a.dart', 'apps/game/lib/ui/b.dart']);
      expect(v, violation('apps/game/lib/ui/b.dart', '소유: ui'));
      expect(v, hasLength(1));
    });

    test('계약은 어느 레인도 못 고친다', () {
      expect(
        checkLane(cfg, 'lane/economy/summon', ['packages/game_core/lib/contracts.dart']),
        violation('packages/game_core/lib/contracts.dart', 'main 전용'),
      );
    });

    test('자기 이름의 계획·요청서·진척 문서는 허용, 남의 것은 실패', () {
      final v = checkLane(cfg, 'lane/ui', [
        'docs/plans/active/ui-tabs.md',
        'docs/contracts/requests/ui-fleet-view.md',
        'docs/progress/ui.md',
        'docs/progress/render.md',
      ]);
      expect(v.map((e) => e.path), ['docs/progress/render.md']);
    });

    test('테이블을 바꾼 레인은 생성물 tables.g.dart도 바꿀 수 있다', () {
      expect(checkLane(cfg, 'lane/economy', ['packages/game_data/tables/ads.json', tablesOut]), isEmpty);
      expect(checkLane(cfg, 'lane/economy', ['packages/game_data/tables/skills.json']), hasLength(1));
    });

    test('main과 레인이 아닌 브랜치는 검사하지 않는다', () {
      expect(checkLane(cfg, 'main', ['anything']), isEmpty);
      expect(checkLane(cfg, 'lane/unknown', ['a']).single.message, contains('LANES.yaml에 없습니다'));
    });
  });

  test('git status 첫 줄이 unstaged 수정(" M")이어도 경로를 자르지 않는다', () {
    expect(parsePorcelain(' M docs/plans/a.md\nA  lib/b.dart\nR  old.dart -> new.dart\n?? "c d.md"'), [
      'docs/plans/a.md',
      'lib/b.dart',
      'new.dart',
      'c d.md',
    ]);
  });

  test('실제 저장소는 모든 검사를 통과한다', () {
    expect([...checkDeps(realRoot), ...checkRules(realRoot), ...checkTablesFresh(realRoot)], isEmpty);
  });
}
