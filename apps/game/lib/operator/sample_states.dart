import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:pirate_dot/operator/sample_states.g.dart';

/// 샘플 상태 이름 (생성물 순서: new_player, stage37_midgame, boss_fight, all_crews_mythic).
List<String> get sampleStateNames => sampleStatesJson.keys.toList();

/// 샘플 상태 하나. 세이브와 같은 길(SaveCodec.migrate)로 읽어 스키마가 바뀌어도 따라간다.
GameState loadSampleState(String name) {
  final text = sampleStatesJson[name];
  if (text == null) throw ArgumentError.value(name, 'name', 'unknown sample state');
  return GameState.fromJson(SaveCodec.migrate(jsonDecode(text) as Map<String, dynamic>));
}
