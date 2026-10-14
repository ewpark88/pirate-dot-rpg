import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';

/// 렌더 레인용 실제 엔진 전투 기록 (`fixtures/events/sample_battle.jsonl`).
///
/// 장면: 스테이지 31(범선, 슬롯 4) — 곡사·직사·관통·충격이 무리를 범위로 맞히고(AoeDamageSum), 함성 게이지가 차서 궁극기·동시 처치,
/// 중간에 보스 등장(이 편성으로는 못 잡는다). 같은 시드라 매번 같은 기록이 나온다.
List<RecordedTick> engineBattle(GameTables t, {int ticks = 300}) {
  final start = DateTime.utc(2026, 11);
  final state = GameState.newGame(playerId: 'record', seed: 2026, now: start).copyWith(
    progress: const Progress(stage: 31, bestStage: 31, rage: 0.95),
    ship: const ShipState(parts: {'cannon': 24, 'hull': 40, 'sail': 10, 'crowsnest': 15, 'cargo': 10}),
    crews: const {
      'octo': CrewState(level: 30),
      'pang': CrewState(level: 28),
      'sword': CrewState(level: 26),
      'turtle': CrewState(level: 24),
    },
    collection: const {'octo', 'pang', 'sword', 'turtle'},
  );
  final engine = CoreEngine(tables: t, clock: ManualClock(start), initial: state);
  final out = <RecordedTick>[];
  for (var i = 0; i < ticks; i++) {
    if (i == ticks ~/ 2) engine.enqueue(const OpSpawnBoss());
    engine.tick();
    out.add(RecordedTick(engine.state.battle!, engine.drainEvents()));
  }
  return out;
}

/// 앱 데모용 Dart 상수 파일 (`apps/game/lib/render/demo/sample_battle.g.dart`).
String recordingDartSource(String jsonl) =>
    '''
// 생성물 — 고치지 마세요. `dart run game_cli export-events`가 fixtures/events/sample_battle.jsonl과 함께 씁니다.
// ignore_for_file: lines_longer_than_80_chars

/// 실제 엔진 전투 기록(JSONL). `decodeRecording(sampleBattleJsonl)`로 읽는다.
const String sampleBattleJsonl = r\'\'\'
$jsonl\'\'\';
''';
