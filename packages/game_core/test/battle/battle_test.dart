// 전투 M1 수용 기준 (docs/specs/battle-m1-core.md). 번호는 스펙의 수용 기준 번호.
import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/fleet.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  final tables = GameTables.load();
  final w = tables.waves;
  final start = DateTime.utc(2026, 11);

  GameState game({int stage = 1, Map<String, CrewState> crews = const {}, double rage = 0}) =>
      GameState.newGame(playerId: 't', seed: 7, now: start).copyWith(
        settings: const Settings(battleView: 'side'), // 옆모습 전용 — T4-2(SideGeometry 삭제)에서 지우거나 탑다운으로
        progress: Progress(stage: stage, bestStage: stage, rage: rage),
        crews: crews,
      );
  CoreEngine engineOf(GameState s) => CoreEngine(tables: tables, clock: ManualClock(start), initial: s);

  late List<GameEvent> events;
  SystemContext ctxOf(int seed) =>
      SystemContext(tables: tables, clock: ManualClock(start), rng: XorShiftRng(seed), onEvent: events.add);
  setUp(() => events = []);

  Foe foeAt(double x, double y, {BigNum? hp}) => Foe(
    id: x.toInt() * 1000 + y.toInt(),
    kind: 'crab',
    layer: 'surface',
    x: x,
    y: y,
    maxHp: hp ?? BigNum.from(1e9),
    speed: 0,
    attack: BigNum.one,
    gold: BigNum.from(10),
  );
  Field fieldWith(List<Foe> foes) =>
      Field(stage: 1, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100))..foes.addAll(foes);
  FamilyDef family(String id) => tables.skills.byId(id);
  String crewOf(String familyId, [int nth = 0]) =>
      tables.crews.crews.where((c) => c.family == familyId).elementAt(nth).id;

  test('1. 첫 틱에 mobCountAt(1)마리가 오른쪽에 생기고, HP 합 = 단일 HP × mobPoolAt(1) × waveHpPoolFactor', () {
    final e = engineOf(game())..tick();
    final enemies = e.state.battle!.enemies;
    expect(enemies, hasLength(w.mobCountAt(1)));
    expect(enemies.every((x) => x.x >= w.field.spawnX - w.field.width && x.hpRatio == 1), isTrue);

    final f = fieldWith([]);
    spawnWave(f, 1, ctxOf(1), kind: 'crab'); // crab hpScale 1
    final total = f.foes.fold(BigNum.zero, (s, x) => s + x.maxHp);
    expect(total.closeTo(BigNum.from(w.hpBase * w.mobPoolAt(1) * w.waveHpPoolFactor)), isTrue);
  });

  test('2. 아무 공격도 없으면 적이 배에 닿고 ShipDamaged가 나온다', () {
    final e = engineOf(game())..enqueue(const OpSetWave(count: 1, enemyKind: 'crab'));
    final secs = (w.field.spawnX - w.field.shipX) / tables.regions.enemies['crab']!.speed;
    e.advance((secs * 1000 / w.tickMs).ceil() + 2);
    final hits = e.drainEvents().whereType<ShipDamaged>();
    expect(hits, isNotEmpty);
    expect(e.state.battle!.shipHp < e.state.battle!.shipHpMax, isTrue);
  });

  test('3. 자동 편성: 슬롯 수만큼, 같은 계열 최대 2명, 선장 = 최고 등급', () {
    final crews = {
      crewOf('lob'): const CrewState(level: 20),
      crewOf('lob', 1): const CrewState(level: 19),
      crewOf('lob', 2): const CrewState(level: 18),
      crewOf('direct'): const CrewState(level: 5),
      crewOf('pierce'): const CrewState(level: 32), // hero
      crewOf('skip'): const CrewState(level: 2),
      crewOf('air'): const CrewState(level: 3),
    };
    final s = game(crews: crews);
    final fleet = autoFleet(s, tables, tables.shipTiers.tierAt(1).slots);
    expect(fleet, hasLength(3));
    expect(fleet.where((id) => tables.crews.byId(id).family == 'lob').length, lessThanOrEqualTo(2));
    expect(fleet.first, crewOf('pierce'));
    expect(captainOf(fleet, s, tables), crewOf('pierce'));
  });

  test('4. 원형 범위: 8마리를 맞히고 7·8번째는 overflowDamage, AoeDamageSum이 나온다', () {
    final foes = [for (var i = 0; i < 8; i++) foeAt(200, 100.0 + i)];
    final v = aim(family('lob').attack, foes, w, XorShiftRng(1))!;
    expect(v.hits, hasLength(8));
    expect(
      [for (final h in v.hits) h.factor],
      [
        ...List<double>.filled(w.aoeFullDamageTargets, 1),
        w.aoeOverflowDamage,
        w.aoeOverflowDamage,
      ],
    );

    final f = fieldWith(foes)..guns = [Gun.of(tables, crewOf('lob'), power: 1)];
    Round(f, ctxOf(1), CombatStats.of(game(), tables), rage: 0).fireGuns();
    expect(events.whereType<AoeDamageSum>(), hasLength(1));
    expect(events.whereType<Damage>(), hasLength(8));
  });

  test('5. 연쇄: 한 번 튈 때마다 chainFalloff씩 줄어든다', () {
    final foes = [for (var i = 0; i < 4; i++) foeAt(100.0 + i * 10, 100)];
    final hits = spread(foes, w, falloff: true);
    for (var i = 1; i < hits.length; i++) {
      expect(hits[i].factor, closeTo(hits[i - 1].factor * (1 - w.chainFalloff), 1e-12));
    }
    final v = aim(family('skip').attack, foes, w, XorShiftRng(1))!;
    expect(v.hits.first.foe.x, 100); // 배에 가장 가까운 적부터
  });

  test('6. 0.5초 안에 5마리 처치 → 창이 닫히면 MultiKill(5) + 히트스톱', () {
    final foes = [for (var i = 0; i < 5; i++) foeAt(200, 100.0 + i, hp: BigNum.from(1e-3))];
    final f = fieldWith(foes)..guns = [Gun.of(tables, crewOf('lob'), power: 1)];
    final r = Round(f, ctxOf(1), CombatStats.of(game(), tables), rage: 0)..fireGuns();
    expect(events.whereType<Kill>(), hasLength(5));
    final goldBefore = r.gold;
    for (var i = 0; i * w.tickMs <= w.multiKillWindowSec * 1000; i++) {
      r.tickCombo();
    }
    expect(events.whereType<MultiKill>().single.count, 5);
    expect(events.whereType<HitStop>().map((h) => h.reason), contains('multiKill4'));
    expect(r.gold > goldBefore, isTrue); // 동시 처치 골드 보너스
  });

  test('7. 함성 게이지가 가득이면 다음 틱에 궁극기, 게이지 0', () {
    final e = engineOf(game(crews: {crewOf('skip'): const CrewState(level: 3)}, rage: tables.skills.rageMax))..tick();
    final ult = e.drainEvents().whereType<UltimateCast>().single;
    expect(ult.crewId, crewOf('skip'));
    expect(ult.ultimateId, family('skip').ultimateId);
    // 게이지는 0으로 돌아간다(같은 틱 스킬 처치로 조금 다시 찰 수는 있다).
    expect(e.state.progress.rage, lessThan(tables.skills.rageMax * 0.1));
  });

  test('처치하면 골드가 지갑에 들어가고 게이지가 찬다', () {
    final e = engineOf(game(crews: {crewOf('direct'): const CrewState(level: 30)}))..advance(40 * 1000 ~/ w.tickMs);
    final kills = e.drainEvents().whereType<Kill>().toList();
    expect(kills, isNotEmpty);
    expect(e.state.wallet.gold.isZero, isFalse);
    expect(e.state.progress.rage, greaterThan(0));
    // 일일 퀘스트 '처치' 진행 (경제 addQuestProgress를 전투가 부른다).
    final killQuest = tables.meta.dailyQuests.firstWhere((q) => q.str('type') == 'kill');
    expect(e.state.daily.quests[killQuest.str('id')], kills.length.clamp(0, killQuest.integer('target')));
  });

  test('9. 보스를 잡으면 스테이지 +1·젬·보스 카드(스테이지 올리기 전 기준)·저장 요청', () {
    final crews = {crewOf('direct'): const CrewState(level: 40), crewOf('lob'): const CrewState(level: 40)};
    final s = game(stage: 5, crews: crews).copyWith(ship: const ShipState(parts: {'cannon': 30}));
    final e = engineOf(
      s.copyWith(battle: BattleView.empty.copyWith(chest: const ChestView(x: 150, y: 100, ticksLeft: 9999))),
    )..enqueue(const OpSpawnBoss());
    final ev = <GameEvent>[];
    for (var i = 0; i < 30 * 1000 ~/ w.tickMs && e.state.progress.stage == 5; i++) {
      ev.addAll((e..tick()).drainEvents());
    }
    expect(ev.whereType<BossCleared>().single.stage, 5);
    expect(ev.whereType<SaveRequested>().map((x) => x.reason), contains('bossCleared'));
    expect(e.state.progress.stage, 6);
    expect(e.state.wallet.gems, w.bossGems);
    expect(e.state.battle!.chest?.x, 150, reason: '보스를 잡아도 떠 있던 보물상자는 남는다');
    final cards =
        e.state.crews.values.fold(0, (n, c) => n + c.cards) + e.state.crews.values.fold(0, (n, c) => n + c.exp);
    expect(cards, greaterThan(0));
  });

  test('튜토리얼 3단계: 스테이지 3 첫 보스는 HP × tutorialFailHpMultiplier', () {
    final normal = Field(stage: 3, shipHpMax: BigNum.one, shipHp: BigNum.one);
    startBoss(normal, w.tutorialFailStage, ctxOf(1));
    final hard = Field(stage: 3, shipHpMax: BigNum.one, shipHp: BigNum.one);
    startBoss(hard, w.tutorialFailStage, ctxOf(1), hpScale: w.tutorialFailHpMultiplier);
    expect(hard.foes.first.maxHp.closeTo(normal.foes.first.maxHp.times(w.tutorialFailHpMultiplier)), isTrue);

    // 엔진: 튜토리얼 3단계면 첫 보스를 30초 안에 못 잡고 파밍으로 (약한 시작 편성).
    final s =
        game(
          stage: w.tutorialFailStage,
          crews: {for (final id in tables.meta.startingCrews) id: const CrewState()},
        ).copyWith(
          tutorialStep: w.tutorialFailStage,
          progress: Progress(stage: w.tutorialFailStage, bestStage: w.tutorialFailStage, wave: w.wavesPerStage),
        );
    final e = engineOf(s)..advance(60 * 1000 ~/ w.tickMs);
    expect(e.drainEvents().whereType<BossFailed>(), isNotEmpty);
  });

  test('버프: 순풍 중 골드 ×goldMultiplier·배속 ×speedMultiplier, 함포 지원 중 피해 +damageBonus', () {
    final reward = {for (final p in tables.ads.placements) p.id: p.reward};
    final buffs = Buffs(
      tailwindUntil: start.add(const Duration(hours: 1)),
      bossSupportUntil: start.add(const Duration(minutes: 1)),
    );
    final s = game(crews: {crewOf('direct'): const CrewState(level: 5)}).copyWith(buffs: buffs);
    final on = CombatStats.of(s, tables, now: start);
    final off = CombatStats.of(s, tables, now: start.add(const Duration(hours: 2)));
    expect(on.goldMultiplier, closeTo(off.goldMultiplier * reward['tailwind']!.number('goldMultiplier'), 1e-9));
    // off.bonus = 보유 효과·도감(damageBonus) — 버프·조각은 그 위에 더해진다.
    expect(on.bonus - off.bonus, closeTo(reward['bossSupport']!.number('damageBonus'), 1e-9));
    final e = engineOf(s)..tick();
    expect(e.state.battle!.speed, reward['tailwind']!.integer('speedMultiplier'));

    // 환생 조각 10개 = 피해·골드 +bonusPerPiece × 10
    final pieces = s.copyWith(
      wallet: s.wallet.copyWith(mapPieces: 10),
      progress: s.progress.copyWith(mapPiecesEarned: 10), // 환생 v2: 보너스는 누계 기준
    );
    final per = tables.meta.rebirth.number('bonusPerPiece');
    final withPieces = CombatStats.of(pieces, tables, now: start.add(const Duration(hours: 2)));
    expect(withPieces.bonus - off.bonus, closeTo(per * 10, 1e-9));
    expect(withPieces.goldMultiplier, closeTo(off.goldMultiplier * (1 + per * 10), 1e-9));
  });

  test('10. 같은 시드·같은 명령이면 600틱 이벤트가 완전히 같다', () {
    String run() {
      final e = engineOf(game(stage: 12, crews: {for (final f in crewFamilies) crewOf(f): const CrewState(level: 10)}))
        ..advance(300)
        ..enqueue(const TriggerUltimate())
        ..advance(300);
      return jsonEncode([for (final ev in e.drainEvents()) ev.toJson()]);
    }

    final a = run();
    expect(a, run());
    expect(a.length, greaterThan(1000));
  });

  group('빠른 항해 (환생 뒤 bestStage × rebirthSkip.fraction 이하, 사용자 결정 2026-10-15)', () {
    final crews = {crewOf('direct'): const CrewState(level: 40)};

    /// 첫 적이 나타날 때까지 돌리고, 그 적이 보스인지.
    bool firstIsBoss(Progress p) {
      final e = engineOf(game(crews: crews).copyWith(progress: p));
      for (var i = 0; i < 200 && (e.state.battle?.enemies.isEmpty ?? true); i++) {
        e.tick();
      }
      return e.state.battle!.enemies.any((x) => x.boss);
    }

    test('환생 뒤 낮은 스테이지는 파 없이 바로 보스', () {
      expect(firstIsBoss(const Progress(stage: 10, bestStage: 50, rebirths: 1)), isTrue);
    });

    test('첫 회차·경계 위 스테이지는 그대로 파부터', () {
      final limit = (50 * w.rebirthSkip.fraction).ceil();
      for (final p in [
        const Progress(stage: 10, bestStage: 50),
        Progress(stage: limit + 1, bestStage: 50, rebirths: 1),
      ]) {
        expect(firstIsBoss(p), isFalse, reason: '${p.toJson()}');
      }
    });
  });
}
