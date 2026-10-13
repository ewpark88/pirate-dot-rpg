import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:game_core/game_core.dart' hide Command;

/// `save inspect save.json` — 세이브 검증(체크섬), 마이그레이션 결과 출력.
class SaveCommand extends Command<int> {
  SaveCommand() {
    addSubcommand(_InspectCommand());
  }

  @override
  String get name => 'save';

  @override
  String get description => '세이브 파일 도구';
}

class _InspectCommand extends Command<int> {
  @override
  String get name => 'inspect';

  @override
  String get description => '세이브 검증 + 최신 버전으로 마이그레이션한 결과 출력';

  @override
  Future<int> run() async {
    if (argResults!.rest.length != 1) usageException('세이브 파일 경로 하나를 주세요');
    final file = File(argResults!.rest.single);
    final text = file.readAsStringSync();
    final from = (jsonDecode(text) as Map)['schemaVersion'];
    try {
      final state = SaveCodec.decode(text);
      stdout
        ..writeln('OK  ${file.path}')
        ..writeln('    schemaVersion $from → $currentSchemaVersion, 체크섬 일치')
        ..writeln(
          '    스테이지 ${state.progress.stage} (최고 ${state.progress.bestStage}), '
          '골드 ${state.wallet.gold.format()}, 젬 ${state.wallet.gems}, 선원 ${state.crews.length}명'
          '${state.operator ? ', 운영자 표식' : ''}',
        )
        ..writeln(const JsonEncoder.withIndent('  ').convert(state.toJson()));
      return 0;
    } on SaveCorruptException catch (e) {
      stderr.writeln('깨진 세이브: ${e.reason}');
      return 1;
    }
  }
}
