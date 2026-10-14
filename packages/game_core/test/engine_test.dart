import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 테스트용 시스템: UpgradePart를 받으면 레벨을 올리고, 매 틱 이벤트를 하나 낸다.
class _Probe implements GameSystem {
  int updates = 0;

  @override
  GameState? handle(GameState s, Command c, SystemContext ctx) => switch (c) {
    UpgradePart(:final part) => s.copyWith(ship: s.ship.withLevel(part, s.ship.level(part) + 1)),
    _ => null,
  };

  @override
  GameState update(GameState s, SystemContext ctx) {
    updates++;
    if (ctx.tick == 2) ctx.emit(HitStop(ctx.tick, ticks: 3, reason: 'crit'));
    return s;
  }
}

void main() {
  final tables = GameTables.load();
  final start = DateTime.utc(2026, 11);
  late _Probe probe;
  late CoreEngine engine;

  setUp(() {
    probe = _Probe();
    engine = CoreEngine(
      tables: tables,
      clock: ManualClock(start),
      initial: GameState.newGame(playerId: 'p', seed: 1, now: start),
      systems: [probe],
    );
  });

  test('틱 길이는 waves.json tickMs (20Hz)', () {
    expect(engine.tickLength, const Duration(milliseconds: 50));
  });

  test('명령은 다음 틱에 적용된다', () {
    engine.enqueue(const UpgradePart('cannon'));
    expect(engine.state.ship.level('cannon'), 0);
    engine.tick();
    expect(engine.state.ship.level('cannon'), 1);
  });

  test('처리하는 시스템이 없는 명령은 unhandled에 남는다', () {
    engine
      ..enqueue(const Summon(count: 10))
      ..tick();
    expect(engine.unhandled.single, isA<Summon>());
  });

  test('히트스톱 동안 시뮬이 멈춘다', () {
    engine.advance(3); // 틱 0,1,2 — 틱 2에서 3틱 히트스톱
    expect(probe.updates, 3);
    engine.advance(3);
    expect(probe.updates, 3, reason: '멈춘 3틱 동안 update 없음');
    expect(engine.state.battle!.tick, 3);
    engine.tick();
    expect(probe.updates, 4);
  });

  test('운영자 명령은 세이브에 표식을 남긴다', () {
    engine
      ..enqueue(const OpSetSpeed(0))
      ..tick();
    expect(engine.state.operator, isTrue);
    expect(probe.updates, 0, reason: '배속 0 = 일시정지');
    engine
      ..enqueue(const OpStepTick())
      ..tick();
    expect(probe.updates, 1, reason: '1틱 진행');
  });

  test('설정 바꾸기', () {
    engine
      ..enqueue(const SetSetting('shake', false))
      ..tick();
    expect(engine.state.settings.shake, isFalse);
  });

  test('같은 시드 → 같은 난수 (결정론)', () {
    final a = XorShiftRng(42);
    final b = XorShiftRng(42);
    expect(List.generate(100, (_) => a.nextInt(1000)), List.generate(100, (_) => b.nextInt(1000)));
    expect(XorShiftRng(0).nextDouble(), isNot(0));
  });

  test('이벤트는 drain하면 비워진다', () {
    engine.advance(3);
    expect(engine.drainEvents().whereType<HitStop>(), hasLength(1));
    expect(engine.drainEvents(), isEmpty);
  });

  test('AckSummonResult는 lastSummon을 지운다 (엔진 공통 명령)', () {
    final e =
        CoreEngine(
            tables: tables,
            clock: ManualClock(start),
            initial: GameState.newGame(playerId: 'p', seed: 1, now: start).copyWith(
              lastSummon: const [SummonResult(crewId: 'octo', rarity: 'hero', isNew: true)],
            ),
            systems: const [],
          )
          ..enqueue(const AckSummonResult())
          ..tick();
    expect(e.state.lastSummon, isNull);
    expect(e.unhandled, isEmpty);
  });
}
