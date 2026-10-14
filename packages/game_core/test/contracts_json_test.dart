import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

/// 계약 타입의 JSON 왕복. 리플레이·운영자 로그·렌더 픽스처가 이 형식에 기대므로 깨지면 안 된다.
void main() {
  final state = GameState.newGame(playerId: 'p', seed: 3, now: DateTime.utc(2026, 11));

  final commands = <Command>[
    const UpgradePart('cannon', times: 5),
    const Summon(count: 10),
    const MergeAllCards(),
    const PromoteCrew('octo'),
    const ChallengeBoss(),
    const TriggerUltimate(),
    const TapChest(),
    const GrantAdReward(AdPlacement.chest),
    const ClaimOffline(),
    const ClaimDaily(),
    const ClaimDaily('kill_500'),
    const ClaimAttendance(),
    const SkipTutorial(),
    const TutorialAck(3),
    const AckSummonResult(),
    const GrantAdReward(AdPlacement.chest, choice: 'gems'),
    const Rebirth(),
    const ExchangeToken('manta'),
    const SetSetting('shake', false),
    const OpSetCrew('volke', level: 75),
    const OpSetFleet(['octo']),
    const OpSetFleet(null),
    OpGrant(gold: BigNum.parse('1e30'), gems: 5, cards: const {'octo': 3}),
    const OpSetShip({'cannon': 100}),
    const OpJumpStage(150),
    const OpSetWave(count: 14, enemyKind: 'gull'),
    const OpSpawnBoss(),
    const OpSetInvincible(on: true),
    const OpSetSpeed(4),
    const OpStepTick(),
    const OpCastSkill('orca'),
    const OpZeroCooldown(on: true),
    const OpAdvanceClock(Duration(hours: 8)),
    const OpRebirthNow(),
    OpLoadState(state),
    const OpReset(),
    const OpSpawnChest(),
    const OpSetTutorial(null),
    const OpGrantTailwind(Duration(minutes: 30)),
  ];

  test('모든 명령 JSON 왕복', () {
    for (final c in commands) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson(), reason: c.type);
    }
  });

  final events = <GameEvent>[
    const AttackFired(1, crewId: 'octo', family: 'lob', targetIds: [1, 2], x: 10, y: 20),
    Damage(1, targetId: 1, amount: BigNum.from(12), crit: true, crewId: 'pang'),
    AoeDamageSum(1, total: BigNum.from(40), x: 1, y: 2),
    Kill(2, targetId: 1, gold: BigNum.from(3), x: 1, y: 2),
    const MultiKill(2, count: 5),
    const SkillCast(3, crewId: 'orca', skillId: 'skip_splash', x: 1, y: 2),
    const SkillCast(3, crewId: 'volke', skillId: 'lob_rain', x: 1, y: 2, scope: 'screen'),
    const ZoneSpawned(3, crewId: 'jelly', x: 10, y: 120, radius: 16, ticks: 40),
    const UltimateCast(3, crewId: 'orca', ultimateId: 'ult_tidal_wave'),
    const HitStop(3, ticks: 2, reason: 'ultimate'),
    ShipDamaged(4, amount: BigNum.from(5), hpRatio: 0.9),
    const WaveCleared(5, wave: 1),
    const BossSpawned(6, kind: 'enemy_ship', timeLimitTicks: 600),
    const BossCleared(7, stage: 5, gems: 5),
    const BossFailed(7, stage: 5),
    const StageAdvanced(8, stage: 6),
    const BestStageUpdated(8, stage: 6),
    const ShipTierUp(8, tierId: 'sloop'),
    const PartUpgraded(9, part: 'cannon', level: 25),
    const PartMilestone(9, part: 'cannon', level: 25),
    const CrewSummoned(9, results: [(crewId: 'octo', rarity: 'common')]),
    const CrewPromoted(9, crewId: 'octo', rarity: 'rare'),
    const ChestSpawned(10, x: 200, y: 90),
    ChestOpened(10, gold: BigNum.from(100)),
    OfflineReward(0, gold: BigNum.parse('1e9'), cards: 3, seconds: 28800),
    const SaveRequested(11, reason: 'upgrade'),
  ];

  test('모든 이벤트 JSON 왕복', () {
    for (final e in events) {
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson(), reason: e.type);
    }
  });

  test('전투 기록 JSONL 왕복', () {
    final ticks = [RecordedTick(BattleView.empty, events), const RecordedTick(BattleView.empty, [])];
    final again = decodeRecording(encodeRecording(ticks));
    expect(again.map((t) => t.toJson()), ticks.map((t) => t.toJson()));
  });

  test('모르는 type은 FormatException', () {
    expect(() => Command.fromJson(const {'type': 'fly'}), throwsFormatException);
    expect(() => GameEvent.fromJson(const {'t': 0, 'type': 'fly'}), throwsFormatException);
  });
}
