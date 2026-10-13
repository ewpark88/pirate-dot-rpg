import 'package:args/command_runner.dart';
import 'package:game_cli/src/repo_root.dart';

/// `balance crews` — 40명 × 5등급 × 대표 레벨 점수표, ±10% 검사 (설계서 4.8).
/// `balance diff` — 테이블 변경 전후 시뮬 비교. 경제 레인(S2) 담당.
class BalanceCommand extends Command<int> {
  BalanceCommand() {
    addSubcommand(_Pending('crews', '선원 파워 예산 점수표 (±10% 벗어나면 실패)'));
    addSubcommand(_Pending('diff', '테이블 변경 전후 시뮬 비교 리포트'));
  }

  @override
  String get name => 'balance';

  @override
  String get description => '밸런스 검사·리포트';
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
