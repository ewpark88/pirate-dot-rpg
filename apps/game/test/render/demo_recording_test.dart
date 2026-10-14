import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/demo/sample_battle.g.dart';

void main() {
  test('수용 기준 11: 데모 기록 상수 = fixtures/events/sample_battle.jsonl', () {
    final file = File('../../fixtures/events/sample_battle.jsonl').readAsStringSync();
    final fromConst = decodeRecording(sampleBattleJsonl);
    final fromFile = decodeRecording(file);
    expect(fromConst.length, fromFile.length);
    expect(encodeRecording(fromConst), encodeRecording(fromFile));
  });
}
