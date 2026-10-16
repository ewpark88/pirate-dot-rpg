import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/battle_system.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 현상금 전투(탑다운 B1, 계획 platform-bounty-topdown.md). 경제 몫(StartBounty → 티켓 −1·active)은 B2 전이라
/// 그 역할만 하는 가짜 시스템을 앞에 둔다(엔진은 경제 → 전투 순서로 명령을 넘긴다).
class _FakeBountyEconomy implements GameSystem {
  @override
  GameState? handle(GameState s, Command c, SystemContext ctx) {
    if (c is! StartBounty) return null;
    final b = s.bounty ?? const BountyState(tickets: 3);
    if (b.tickets <= 0 || b.active != null) return s;
    return s.copyWith(
      bounty: b.copyWith(
        tickets: b.tickets - 1,
        active: BountyActive(bossId: c.bossId, tier: c.tier),
      ),
    );
  }

  @override
  GameState update(GameState s, SystemContext ctx) => s;
}

void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  final boss = bountyBosses(t).first;
  int ticksFor(double sec) => (sec * 1000 / t.waves.tickMs).round();

  GameState game({int crewLevel = 5, int cannon = 0, BountyActive? active, int tickets = 3}) =>
      GameState.newGame(
        playerId: 'b',
        seed: 7,
        now: start,
        crews: t.meta.startingCrews,
      ).copyWith(
        progress: const Progress(stage: 10, bestStage: 10),
        crews: {for (final id in t.meta.startingCrews) id: CrewState(level: crewLevel)},
        ship: ShipState(parts: {...const ShipState().parts, 'cannon': cannon}),
        bounty: BountyState(tickets: tickets, active: active),
        clearTutorial: true,
      );

  CoreEngine engineOf(GameState s) => CoreEngine(
    tables: t,
    clock: ManualClock(start),
    initial: s,
    systems: [_FakeBountyEconomy(), const EconomySystem(), BattleSystem()],
  );

  /// 본 전투를 조금 돌린 뒤 현상금을 시작한다(앱이 켜져 있는 중 = 중단이 아님).
  (CoreEngine, List<GameEvent>) started({int tier = 1, int crewLevel = 5, int cannon = 0, bool invincible = false}) {
    final e = engineOf(game(crewLevel: crewLevel, cannon: cannon))
      ..advance(ticksFor(2))
      ..drainEvents();
    if (invincible) e.enqueue(const OpSetInvincible(on: true));
    e
      ..enqueue(StartBounty(boss, tier))
      ..tick()
      ..tick(); // 경제가 active를 정한 다음 틱에 전투가 열린
    return (e, e.drainEvents());
  }

  List<GameEvent> runUntil(CoreEngine e, bool Function(GameEvent ev) done, double maxSec) {
    final out = <GameEvent>[];
    for (var i = 0; i < ticksFor(maxSec); i++) {
      e.tick();
      final evs = e.drainEvents();
      out.addAll(evs);
      if (evs.any(done)) break;
    }
    return out;
  }

  test('시작: 전장이 현상금 보스 하나로, BountyStarted, 스테이지는 그대로', () {
    final (e, evs) = started();
    final b = e.state.battle!;
    expect(evs.whereType<BountyStarted>().single.bossId, boss);
    expect(b.bounty?.bossId, boss);
    expect(b.enemies.where((x) => x.boss).single.kind, boss);
    expect(b.enemies.where((x) => !x.boss && x.kind != '${boss}_tentacle'), isEmpty, reason: '무리 없음');
    expect(e.state.progress.stage, 10);
    expect(e.state.bounty!.tickets, 2);
  });

  test('처치: BountyCleared·보상·깬 단계 기록, active 지움, 같은 스테이지 본 전투로', () {
    final (e, _) = started(crewLevel: 60, cannon: 150, invincible: true);
    final evs = runUntil(e, (ev) => ev is BountyCleared || ev is BountyFailed, 40);
    final cleared = evs.whereType<BountyCleared>().single;
    expect(cleared.tier, 1);
    expect(e.state.bounty!.cleared[boss], 1);
    expect(e.state.bounty!.active, isNull);
    expect(e.state.bounty!.tickets, 2, reason: '성공은 티켓을 돌려주지 않는다');
    expect(e.state.progress.stage, 10);
    e.tick();
    expect(e.state.battle!.bounty, isNull);
  });

  test('시간 초과: BountyFailed(timeout), 티켓 반환, 다음 단계 막대에 피해 비율', () {
    final (e, _) = started(tier: 30, crewLevel: 30, invincible: true);
    final evs = runUntil(e, (ev) => ev is BountyFailed, 60);
    final f = evs.whereType<BountyFailed>().single;
    expect(f.reason, 'timeout');
    expect(e.state.bounty!.tickets, 3);
    expect(e.state.bounty!.active, isNull);
    expect(e.state.bounty!.progress[boss], f.damageRatio);
  });

  test('후퇴: BountyFailed(retreat), 티켓 반환', () {
    final (e, _) = started(tier: 30, invincible: true);
    e
      ..enqueue(const RetreatBounty())
      ..tick();
    final f = e.drainEvents().whereType<BountyFailed>().single;
    expect(f.reason, 'retreat');
    expect(e.state.bounty!.tickets, 3);
  });

  test('침몰: BountyFailed(sunk), 티켓 반환(S1 결정)', () {
    final (e, _) = started(tier: 30);
    final evs = runUntil(e, (ev) => ev is BountyFailed, 60);
    expect(evs.whereType<BountyFailed>().single.reason, 'sunk');
    expect(e.state.bounty!.tickets, 3);
  });

  test('중단: 세이브에 active가 남아 있으면(앱이 꺼졌던 것) 첫 틱에 BountyFailed(interrupted)·티켓 반환', () {
    final e = engineOf(game(active: BountyActive(bossId: boss, tier: 2), tickets: 1))..tick();
    final f = e.drainEvents().whereType<BountyFailed>().single;
    expect(f.reason, 'interrupted');
    expect(e.state.bounty!.tickets, 2);
    expect(e.state.bounty!.active, isNull);
    expect(e.state.battle!.bounty, isNull);
  });

  test('본 전투 멈춤: 현상금 동안 스테이지·파·골드·피버 그대로', () {
    final (e, _) = started(tier: 30, invincible: true);
    final s0 = e.state;
    e.advance(ticksFor(10));
    expect(e.state.progress.stage, s0.progress.stage);
    expect(e.state.progress.wave, s0.progress.wave);
    expect(e.state.wallet.gold.toString(), s0.wallet.gold.toString());
    expect(e.state.battle!.fever, s0.battle!.fever);
  });

  test('결정론: 같은 상태·명령이면 같은 끝', () {
    String run() {
      final (e, _) = started(crewLevel: 60, cannon: 150, invincible: true);
      final evs = runUntil(e, (ev) => ev is BountyCleared || ev is BountyFailed, 40);
      return '${evs.whereType<BountyCleared>().map((c) => c.toJson())}${e.state.battle!.tick}';
    }

    expect(run(), run());
  });
}
