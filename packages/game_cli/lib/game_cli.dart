/// 헤드리스 도구: 화면 없이 게임을 돌리고 검증한다 (docs/GAME_DESIGN.md 6.6).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_cli/src/commands/balance.dart';
import 'package:game_cli/src/commands/export_events.dart';
import 'package:game_cli/src/commands/fixtures.dart';
import 'package:game_cli/src/commands/replay.dart';
import 'package:game_cli/src/commands/save_inspect.dart';
import 'package:game_cli/src/commands/sim.dart';

export 'src/repo_root.dart';
export 'src/scenario/runner.dart';

/// 종료 코드: 0 성공, 1 검증 실패, 2 아직 구현 안 됨, 64 사용법 오류.
Future<int> runCli(List<String> args) async {
  final runner = CommandRunner<int>('game_cli', '해적도트 원정대 헤드리스 도구')
    ..addCommand(SimCommand())
    ..addCommand(BalanceCommand())
    ..addCommand(ReplayCommand())
    ..addCommand(ExportEventsCommand())
    ..addCommand(SaveCommand())
    ..addCommand(FixturesCommand());
  try {
    return await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    stderr.writeln(e);
    return 64;
  }
}
