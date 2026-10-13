import 'package:args/command_runner.dart';
import 'package:game_cli/src/repo_root.dart';

/// `sim --seed 1 --hours 8 --policy greedy` — 헤드리스로 플레이하고 스테이지 도달 시간,
/// 벽 구간, 재화 잔액을 JSON과 표로 출력한다. 경제 레인(S2) 담당.
class SimCommand extends Command<int> {
  SimCommand() {
    argParser
      ..addOption('seed', defaultsTo: '1')
      ..addOption('players', defaultsTo: '1')
      ..addOption('hours', defaultsTo: '2')
      ..addOption('policy', defaultsTo: 'greedy', allowed: ['greedy'])
      ..addFlag('smoke', help: 'check.dart 밸런스 스모크(가상 플레이어 1명 × 2시간)')
      ..addOption('out', help: 'JSON 리포트 경로');
  }

  @override
  String get name => 'sim';

  @override
  String get description => '가상 플레이어로 배속 시뮬레이션';

  @override
  Future<int> run() async => pending('sim', lane: 'economy', milestone: 'M1');
}
