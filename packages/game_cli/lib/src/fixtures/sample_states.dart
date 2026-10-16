import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// UI 레인용 샘플 상태 (fixtures/states/*.json). 운영자 모드의 ‘샘플 상태 불러오기’도 쓴다.
Map<String, GameState> sampleStates(GameTables t) {
  final now = DateTime.utc(2026, 11, 1, 12, 34, 56);
  // 중후반 샘플은 튜토리얼을 끝낸 상태(null). 튜토리얼은 new_player만.
  final base = GameState.newGame(playerId: 'fixture-player', seed: 913377, now: now).copyWith(clearTutorial: true);
  final starter = GameState.newGame(playerId: 'fixture-player', seed: 913377, now: now, crews: t.meta.startingCrews);
  return {
    'new_player': starter.copyWith(battle: _battle(t, stage: 1, fleet: t.meta.startingCrews)),
    'stage37_midgame': _midgame(base, t),
    'boss_fight': base.copyWith(
      summonsTotal: 10,
      progress: const Progress(stage: 5, wave: 3, bestStage: 5),
      wallet: Wallet(gold: BigNum.from(320), gems: 30),
      crews: const {'octo': CrewState(level: 3), 'pang': CrewState(level: 2)},
      collection: const {'octo', 'pang'},
      battle: _battle(t, stage: 5, fleet: const ['octo', 'pang'], boss: true),
    ),
    'all_crews_mythic': base.copyWith(
      summonsTotal: 900,
      operator: true,
      progress: const Progress(stage: 160, bestStage: 160),
      wallet: Wallet(gold: BigNum.parse('3.3e21'), gems: 99999, mapPieces: 120),
      ship: const ShipState(parts: {'cannon': 40, 'hull': 38, 'sail': 30, 'crowsnest': 45, 'cargo': 34}),
      crews: {for (final c in t.crews.crews) c.id: const CrewState(level: 75)},
      collection: {for (final c in t.crews.crews) c.id},
      battle: _battle(t, stage: 160, fleet: const ['volke', 'volt', 'moby', 'orca', 'kraki', 'manta']),
    ),
  };
}

/// 설계서 5.2의 세이브 예시와 같은 상태.
GameState _midgame(GameState base, GameTables t) => base.copyWith(
  wallet: Wallet(gold: BigNum.parse('1.25e6'), gems: 140),
  progress: const Progress(stage: 37, wave: 2, bestStage: 41, rage: 0.4),
  ship: const ShipState(parts: {'cannon': 16, 'hull': 15, 'sail': 18, 'crowsnest': 12, 'cargo': 17}),
  crews: const {
    'octo': CrewState(level: 15, cards: 2),
    'manta': CrewState(level: 46, exp: 3),
    'pang': CrewState(level: 8, cards: 1),
    'pingu': CrewState(level: 22),
  },
  tokens: 12,
  pityCount: 17,
  summonsTotal: 67, // 무료 10연은 이미 씀 (세이브 v2)
  buffs: Buffs(tailwindUntil: DateTime.utc(2026, 11, 1, 14, 4, 56)),
  daily: const DailyState(
    date: '2026-11-01',
    ads: {'chest': 3, 'tailwind': 2},
    quests: {'kill_500': 140},
    attendanceDay: 4,
  ),
  collection: const {'octo', 'manta', 'pang', 'pingu'},
  battle: _battle(t, stage: 37, fleet: const ['manta', 'pingu', 'octo', 'pang']),
);

BattleView _battle(GameTables t, {required int stage, required List<String> fleet, bool boss = false}) {
  final kinds = t.regions.regionAt(stage).enemies;
  final n = boss ? 1 : t.waves.mobCountAt(stage);
  return BattleView(
    shipHp: BigNum.from(60 * stage),
    shipHpMax: BigNum.from(60 * stage),
    bossActive: boss,
    bossTicksLeft: boss ? 400 : 0,
    enemies: [
      for (var i = 0; i < n; i++)
        EnemyView(
          id: i + 1,
          kind: boss ? 'enemy_ship' : kinds[i % kinds.length],
          x: boss ? 250 : 200.0 + (i % 5) * 22,
          y: boss ? 80 : 40.0 + (i ~/ 5) * 30 + (i % 2) * 8,
          hpRatio: boss ? 0.55 : 1,
          layer: boss ? 'surface' : _layerOf(t, kinds[i % kinds.length]),
          boss: boss,
        ),
    ],
    fleet: [for (final id in fleet) FleetSlot(crewId: id, cooldown: 0.3)],
    captainId: fleet.isEmpty ? null : fleet.first,
  );
}

String _layerOf(GameTables t, String kind) => switch (kind) {
  'gull' => 'air',
  'jelly' || 'fish' || 'urchin' => 'underwater',
  _ => 'surface',
};
