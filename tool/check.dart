// 모든 검사. 빠른 것부터 돌고 첫 실패에서 멈춘다 (docs/GAME_DESIGN.md 6.4).
//
//   dart run tool/check.dart          # 매 작업 끝 (Stop 훅도 이것을 부른다)
//   dart run tool/check.dart --full   # + Flutter 위젯·골든 테스트 (PR·CI)
//
// Windows: tool\check.bat, Linux/CI: tool/check.sh — 둘 다 이 파일을 부른다.
import 'dart:convert';
import 'dart:io';

import 'package:pde_tool/harness.dart';

final Directory _root = findRepoRoot();
final bool _isWindows = Platform.isWindows;

Future<void> main(List<String> args) async {
  final full = args.contains('--full');
  final sw = Stopwatch()..start();
  final stages = <(String, Future<_Outcome> Function())>[
    ('생성물 (테이블 임베드·ARB 합치기·gen-l10n)', _generate),
    ('포맷', () => _run('dart', ['format', '--set-exit-if-changed', '--output=none', ..._dartDirs])),
    // 하네스 규칙을 분석기보다 먼저: 0.2초이고, 무엇을 어디로 옮길지 알려 준다.
    ('의존 방향·금지 패턴·레인 소유권', _harnessRules),
    ('정적 분석', () => _run('dart', ['analyze', '--fatal-infos', ..._dartDirs])),
    for (final pkg in ['packages/game_data', 'packages/game_core', 'packages/game_cli', 'tool'])
      ('단위 테스트 $pkg', () => _run('dart', ['test', '--reporter=failures-only'], cwd: pkg)),
    ('시나리오 리플레이', () => _run('dart', ['run', 'game_cli', 'replay', '--all'])),
    ('밸런스 스모크', _balanceSmoke),
    if (full) ('Flutter 위젯·골든 테스트', () => _run('flutter', ['test', '--reporter=failures-only'], cwd: 'apps/game')),
  ];

  for (final (name, stage) in stages) {
    final t = Stopwatch()..start();
    stdout.write('▶ $name ... ');
    final outcome = await stage();
    final secs = (t.elapsedMilliseconds / 1000).toStringAsFixed(1);
    if (outcome.ok) {
      stdout.writeln(outcome.note == null ? 'ok (${secs}s)' : 'ok (${secs}s) — ${outcome.note}');
      continue;
    }
    stdout
      ..writeln('실패 (${secs}s)')
      ..writeln()
      ..writeln(outcome.output.trim())
      ..writeln()
      ..writeln('✗ check 실패: "$name". 위 메시지대로 고친 뒤 다시 실행하세요.');
    exit(1);
  }
  stdout.writeln('\n✓ check 통과 (${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s)${full ? ' --full' : ''}');
}

const _dartDirs = ['packages', 'tool', 'apps/game/lib', 'apps/game/test'];

class _Outcome {
  const _Outcome({required this.ok, this.output = '', this.note, this.exitCode = 0});

  final bool ok;
  final int exitCode;
  final String output;
  final String? note;
}

Future<_Outcome> _run(String exe, List<String> args, {String? cwd}) async {
  final r = await Process.run(
    exe,
    args,
    workingDirectory: cwd == null ? _root.path : '${_root.path}/$cwd',
    runInShell: _isWindows,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return _Outcome(ok: r.exitCode == 0, exitCode: r.exitCode, output: '${r.stdout}${r.stderr}');
}

Future<_Outcome> _generate() async {
  final stale = checkTablesFresh(_root);
  if (stale.isNotEmpty) return _Outcome(ok: false, output: stale.join('\n'));
  final arb = mergeArb(_root);
  final problems = [
    ...arb.violations,
    ...checkTableL10nKeys(_root, arb.keys),
    if (arb.violations.isEmpty) ...checkMergedArbFresh(_root, arb),
  ];
  if (problems.isNotEmpty) return _Outcome(ok: false, output: problems.join('\n'));
  return _run('flutter', ['gen-l10n'], cwd: 'apps/game');
}

Future<_Outcome> _harnessRules() async {
  final lanes = LaneConfig.load(_root);
  final git = gitChanges(_root, lanes.mainBranch);
  final v = [...checkDeps(_root), ...checkRules(_root), ...checkLane(lanes, git.branch, git.changed)];
  return v.isEmpty ? const _Outcome(ok: true) : _Outcome(ok: false, output: v.join('\n'));
}

/// 가상 플레이어 1명 × 2시간. 경제 레인이 sim을 구현하기 전(M1)에는 건너뛴다(game_cli 종료 코드 2 = 미구현).
Future<_Outcome> _balanceSmoke() async {
  final r = await _run('dart', ['run', 'game_cli', 'sim', '--smoke', '--hours', '2']);
  if (r.exitCode == 2) {
    return const _Outcome(ok: true, note: '건너뜀: game_cli sim 미구현 (economy 레인 M1)');
  }
  return r;
}
