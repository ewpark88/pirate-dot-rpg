import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_cli/src/balance/arena.dart';
import 'package:game_cli/src/balance/crew_scores.dart';
import 'package:game_cli/src/balance/report.dart';
import 'package:game_cli/src/repo_root.dart';
import 'package:game_data/game_data.dart';

/// `balance crews` — 40명 × 5등급 × 대표 레벨 점수표, ±10% 검사 (설계서 4.8, docs/specs/render-balance-crews.md).
/// `balance diff` — 테이블 변경 전후 시뮬 비교. 경제 레인(S2) 담당.
class BalanceCommand extends Command<int> {
  BalanceCommand() {
    addSubcommand(_CrewsCommand());
    addSubcommand(_Pending('diff', '테이블 변경 전후 시뮬 비교 리포트'));
  }

  @override
  String get name => 'balance';

  @override
  String get description => '밸런스 검사·리포트';
}

/// 종료 코드: 0 통과, 1 위반(±10% 밖 또는 조합 폭주), 2 측정 오류.
class _CrewsCommand extends Command<int> {
  _CrewsCommand() {
    argParser
      ..addOption('levels', help: '쉼표로 구분한 레벨 (기본 15,30,45,60,75)')
      ..addOption('crews', help: '쉼표로 구분한 선원 id (기본 전체)')
      ..addOption('combos', defaultsTo: '500', help: '6명 조합 표본 수')
      ..addOption('seed', defaultsTo: '1')
      ..addOption('stage', defaultsTo: '2001', help: '적이 죽지 않는 스테이지 (25의 배수 금지)')
      ..addOption('kappa', defaultsTo: '$defaultKappa', help: '배 보호분 환산 (기획 판단, 조정 가능)')
      ..addOption('partner', help: '지원 환산 기준 파트너 (기본 첫 직사 선원)')
      ..addOption('out', help: 'JSON 리포트 경로')
      ..addFlag('quick', negatable: false, help: '레벨 45만, 조합 50 (check용)');
  }

  @override
  String get name => 'crews';

  @override
  String get description => '선원 파워 예산 점수표 (±10% 벗어나면 실패)';

  @override
  Future<int> run() async {
    final a = argResults!;
    final quick = a.flag('quick');
    List<String>? list(String key) =>
        a.option(key)?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final levels = quick ? const [45] : (list('levels')?.map(int.parse).toList() ?? defaultLevels);
    final config = ArenaConfig(seed: int.parse(a.option('seed')!), stage: int.parse(a.option('stage')!));
    final watch = Stopwatch()..start();
    final BalanceReport report;
    try {
      report = scoreCrews(
        GameTables.load(),
        levels: levels,
        crewIds: list('crews'),
        config: config,
        kappa: double.parse(a.option('kappa')!),
        combos: quick ? 50 : int.parse(a.option('combos')!),
        partner: a.option('partner'),
      );
    } on MeasureError catch (e) {
      stderr.writeln('✗ $e');
      return 2;
    }
    stdout
      ..write(balanceMarkdown(report))
      ..writeln()
      ..writeln('측정 ${watch.elapsed.inMilliseconds / 1000}초');
    final out = a.option('out');
    if (out != null) {
      File(out).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report.toJson())}\n');
    }
    return report.passed ? 0 : 1;
  }
}

class _Pending extends Command<int> {
  _Pending(this.name, this.description);

  @override
  final String name;

  @override
  final String description;

  @override
  Future<int> run() async => pending('balance $name', lane: 'economy', milestone: 'M1');
}
