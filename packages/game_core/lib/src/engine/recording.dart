import 'dart:convert';

import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:meta/meta.dart';

/// 전투 기록 한 틱: 전장 스냅샷 + 그 틱에 나온 이벤트.
///
/// `fixtures/events/*.jsonl`의 한 줄. 렌더 레인은 전투 레인을 기다리지 않고
/// 이 기록을 재생해 개발한다(`game_cli export-events`로 갱신).
@immutable
class RecordedTick {
  const RecordedTick(this.frame, this.events);

  factory RecordedTick.fromJson(Json j) => RecordedTick(
    BattleView.fromJson(j['frame'] as Json),
    [for (final e in j['events'] as List) GameEvent.fromJson(e as Json)],
  );

  final BattleView frame;
  final List<GameEvent> events;

  Json toJson() => {
    'frame': frame.toJson(),
    'events': [for (final e in events) e.toJson()],
  };
}

/// JSONL로 쓴다. 한 줄 = 한 틱.
String encodeRecording(Iterable<RecordedTick> ticks) => '${ticks.map((t) => jsonEncode(t.toJson())).join('\n')}\n';

List<RecordedTick> decodeRecording(String jsonl) => [
  for (final line in const LineSplitter().convert(jsonl))
    if (line.trim().isNotEmpty) RecordedTick.fromJson(jsonDecode(line) as Json),
];
