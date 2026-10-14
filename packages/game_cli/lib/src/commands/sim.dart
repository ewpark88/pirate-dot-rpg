import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_cli/src/sim/sim_player.dart';
import 'package:game_cli/src/sim/sim_report.dart';
import 'package:game_data/game_data.dart';

/// `sim --seed 1 --players 1 --hours 2 [--schedule daily] [--out report.json]` — 실제 엔진을 헤드리스로 돌려
/// 설계서 7.2 지표를 표와 JSON으로 출력한다. 경제 레인(S2) 담당.
///
/// 종료 코드: `--smoke`는 목표를 벗어나도 경고만(0), 그 외에는 벗어나면 1.
class SimCommand extends Command<int> {
  SimCommand() {
    argParser
      ..addOption('seed', defaultsTo: '1')
      ..addOption('players', defaultsTo: '1')
      ..addOption('hours', defaultsTo: '2', help: '게임 시작부터의 총 시간(오프라인 포함)')
      ..addOption('policy', defaultsTo: 'greedy', allowed: ['greedy'])
      ..addOption(
        'schedule',
        defaultsTo: 'continuous',
        allowed: ['continuous', 'daily'],
        help: 'continuous: 계속 접속 · daily: 20분 접속 + 8시간 오프라인 반복(설계서 4.3.3 하루 40분)',
      )
      ..addFlag('smoke', help: 'check.dart 밸런스 스모크(가상 플레이어 1명 × 2시간), 벗어나면 경고만')
      ..addOption('out', help: 'JSON 리포트 경로');
  }

  @override
  String get name => 'sim';

  @override
  String get description => '가상 플레이어로 배속 시뮬레이션';

  @override
  Future<int> run() async {
    final a = argResults!;
    final t = GameTables.load();
    final seed = int.parse(a['seed'] as String);
    final players = int.parse(a['players'] as String);
    final total = Duration(minutes: (double.parse(a['hours'] as String) * Duration.minutesPerHour).round());
    final schedule = a['schedule'] == 'daily'
        ? const SimSchedule(online: Duration(minutes: 20), offline: Duration(hours: 8))
        : SimSchedule(online: total);

    final results = [for (var i = 0; i < players; i++) SimPlayer(t, seed: seed + i).run(total, schedule)];
    final checks = judge(t, results);
    stdout.write(formatReport(t, results, checks));

    final out = a['out'] as String?;
    if (out != null) {
      File(out).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(reportJson(results, checks)));
    }
    final missed = checks.where((c) => !c.ok(results.first.played)).toList();
    if (missed.isEmpty) return 0;
    final names = missed.map((c) => c.label).join(', ');
    if (a['smoke'] as bool) {
      stdout.writeln('\n경고: 7.2 목표를 벗어남 — $names (스모크는 경고만, 야간 전체 시뮬은 실패)');
      return 0;
    }
    stderr.writeln('7.2 목표를 벗어남 — $names');
    return 1;
  }
}
