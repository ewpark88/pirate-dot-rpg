import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 수동 편성 (사용자 결정 2026-10-15, ADR-0010): 출전은 사용자가 고르고, ‘자동 편성’ 버튼으로 한 번에 채운다.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  /// 스테이지 [stage]의 배 등급 슬롯 수를 쓰는 편성 상태.
  GameState formed(Map<String, CrewState> crews, List<String?> fleet, {int stage = 1}) => h.newGame().copyWith(
    crews: crews,
    collection: crews.keys.toSet(),
    fleet: fleet,
    fleetInit: true,
    progress: Progress(stage: stage, bestStage: stage),
  );

  int slotsAt(int stage) => t.shipTiers.tierAt(stage).slots;

  /// 슬롯이 4칸 이상인 스테이지.
  final wide = [for (var s = 1; s < 1000; s++) s].firstWhere((s) => slotsAt(s) >= 4);

  group('새 게임·옛 세이브', () {
    test('새 게임은 첫 틱에 시작 선원으로 채워지고, 그 뒤는 사용자 편성', () {
      final now = DateTime.utc(2026, 11);
      final e = CoreEngine(
        tables: t,
        clock: ManualClock(now),
        initial: GameState.newGame(playerId: 'p', seed: 1, now: now, crews: t.meta.startingCrews),
      )..tick();
      expect(e.state.fleetInit, isTrue);
      expect(e.state.fleet.whereType<String>().toSet(), t.meta.startingCrews.toSet());
      expect(e.state.battle!.fleet.map((g) => g.crewId).toSet(), t.meta.startingCrews.toSet());
    });

    test('편성한 적 없는 상태(옛 세이브 v4 → v5)는 첫 틱에 자동 편성으로 채운다 — 기존 체감 유지', () {
      final s0 = h.newGame().copyWith(
        crews: const {'octo': CrewState(level: 5), 'manta': CrewState(level: 46), 'pang': CrewState(level: 8)},
        progress: Progress(stage: wide, bestStage: wide),
      );
      expect(s0.fleetInit, isFalse);
      final s = sys.update(s0, h.ctx);
      expect(s.fleetInit, isTrue);
      expect(s.fleet, autoFleet(s0, t, slotsAt(wide)));
    });

    test('한 번 편성하면 새 선원이 생겨도 자동으로 들어가지 않는다 (빈 칸은 사용자 선택)', () {
      final s0 = formed(const {'octo': CrewState(), 'turtle': CrewState()}, const ['octo'], stage: wide);
      final s = sys.update(s0.copyWith(crews: {...s0.crews, 'manta': const CrewState(level: 46)}), h.ctx);
      expect(s.fleet, ['octo']);
      expect(activeFleet(s, t), ['octo']);
    });
  });

  group('SetFleetSlot', () {
    final crews = {
      'octo': const CrewState(),
      'turtle': const CrewState(),
      'manta': const CrewState(level: 46),
      'pang': const CrewState(),
    };

    test('빈 칸에 보유 선원을 넣는다 · null이면 비운다', () {
      final s0 = formed(crews, const ['octo'], stage: wide);
      final s1 = sys.handle(s0, const SetFleetSlot(2, 'manta'), h.ctx)!;
      expect(s1.fleet, ['octo', null, 'manta']);
      expect(h.of<SaveRequested>(), hasLength(1));
      final s2 = sys.handle(s1, const SetFleetSlot(0), h.ctx)!;
      expect(s2.fleet, [null, null, 'manta']);
      expect(activeFleet(s2, t), ['manta']);
    });

    test('다른 칸에 있던 선원을 넣으면 두 칸이 자리를 바꾼다', () {
      final s0 = formed(crews, const ['octo', 'turtle', 'manta'], stage: wide);
      final s = sys.handle(s0, const SetFleetSlot(0, 'manta'), h.ctx)!;
      expect(s.fleet, ['manta', 'turtle', 'octo']);
    });

    test('미보유 선원·슬롯 밖은 무시 (상태 그대로, 이벤트 없음)', () {
      final s0 = formed(crews, const ['octo'], stage: wide);
      expect(sys.handle(s0, const SetFleetSlot(1, 'kraki'), h.ctx), same(s0));
      expect(sys.handle(s0, SetFleetSlot(slotsAt(wide), 'turtle'), h.ctx), same(s0));
      expect(h.events, isEmpty);
    });

    test('마지막 출전 선원은 내릴 수 없다 — FleetRejected(last), 둘 이상이면 내리기 허용', () {
      final one = formed(const {'octo': CrewState(), 'turtle': CrewState()}, ['octo', null]);
      expect(sys.handle(one, const SetFleetSlot(0), h.ctx)!.fleet, one.fleet);
      expect([h.of<FleetRejected>().single.crewId, h.of<FleetRejected>().single.reason], ['octo', 'last']);
      final two = formed(const {'octo': CrewState(), 'turtle': CrewState()}, ['octo', 'turtle']);
      expect(sys.handle(two, const SetFleetSlot(0), h.ctx)!.fleet.first, isNull);
    });

    test('같은 계열 상한(maxSameFamilyInFleet)을 넘기면 거절하고 FleetRejected', () {
      final max = t.skills.maxSameFamilyInFleet;
      // 상한보다 인원이 많은 계열(계열 v3 뒤 계열마다 2~5명)
      final family = t.crews.crews
          .map((c) => c.family)
          .firstWhere((f) => t.crews.crews.where((c) => c.family == f).length > t.skills.maxSameFamilyInFleet);
      final same = [
        for (final c in t.crews.crews)
          if (c.family == family) c.id,
      ];
      expect(same.length, greaterThan(max), reason: '같은 계열 선원이 상한보다 많아야 검사가 된다');
      var stage = wide;
      while (slotsAt(stage) <= max) {
        stage++;
      }
      final s0 = formed({for (final id in same) id: const CrewState()}, same.take(max).toList(), stage: stage);
      final s = sys.handle(s0, SetFleetSlot(max, same[max]), h.ctx)!;
      expect(s.fleet, s0.fleet);
      expect(h.of<FleetRejected>().single.crewId, same[max]);
      expect(h.of<FleetRejected>().single.reason, 'family');
      // 같은 계열끼리 자리 바꿈은 계열 수가 그대로라 허용
      expect(sys.handle(s0, SetFleetSlot(0, same[1]), h.ctx)!.fleet.take(2), [same[1], same[0]]);
    });
  });

  group('AutoFleet·판정', () {
    test('AutoFleet은 자동 편성 규칙(파워 순·계열 상한)으로 슬롯을 모두 채운다', () {
      final crews = {for (final c in t.crews.crews.take(10)) c.id: CrewState(level: c.num)};
      final s0 = formed(crews, const [], stage: wide);
      final s = sys.handle(s0, const AutoFleet(), h.ctx)!;
      expect(s.fleet, autoFleet(s0, t, slotsAt(wide)));
      expect(s.fleet, hasLength(slotsAt(wide)));
    });

    test('emptySlotCount: 쉬는 보유 선원이 있을 때만 빈 칸 수 (UI 배지)', () {
      final full = slotsAt(wide);
      expect(emptySlotCount(formed(const {'octo': CrewState()}, const ['octo'], stage: wide), t), 0);
      final s = formed(
        const {'octo': CrewState(), 'turtle': CrewState(), 'pang': CrewState()},
        const ['octo'],
        stage: wide,
      );
      expect(emptySlotCount(s, t), (full - 1).clamp(0, 2));
    });

    test('슬롯이 줄면(환생으로 배 등급 하락) 앞 칸만 출전, 뒤 칸 기록은 남는다', () {
      final s = formed(
        const {'octo': CrewState(), 'turtle': CrewState(), 'manta': CrewState(), 'pang': CrewState()},
        const ['octo', 'turtle', 'manta', 'pang'],
      );
      expect(activeFleet(s, t), ['octo', 'turtle', 'manta', 'pang'].take(slotsAt(1)).toList());
      expect(s.fleet, hasLength(4));
    });

    test('오프라인·상자 추정은 출전 편성을 쓴다', () {
      final s = formed(const {'octo': CrewState(), 'manta': CrewState(level: 46)}, const ['octo'], stage: wide);
      expect(offlineFleet(s, t), ['octo']);
    });
  });

  test('명령·이벤트 JSON 왕복', () {
    for (final c in const <Command>[SetFleetSlot(2, 'manta'), SetFleetSlot(0), AutoFleet()]) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson());
    }
    const e = FleetRejected(4, slot: 2, crewId: 'manta', reason: 'family');
    expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
  });

  test('한 번 연 칸은 영구 — 스테이지 30 도달 → 환생 → 4번째 칸·그 선원 출전 유지(사용자 버그 2026-10-17)', () {
    const crews = {'octo': CrewState(), 'manta': CrewState(), 'pang': CrewState(), 'turtle': CrewState(level: 17)};
    final s0 = formed(crews, const ['octo', 'manta', 'pang', 'turtle'], stage: wide);
    expect(fleetSlots(s0, t), 4);
    final e = CoreEngine(tables: t, clock: ManualClock(DateTime.utc(2026, 11)), initial: s0)
      ..enqueue(const OpRebirthNow())
      ..tick();
    expect(e.state.progress.stage, lessThan(wide), reason: '환생하면 스테이지는 처음으로');
    expect(fleetSlots(e.state, t), 4);
    expect(activeFleet(e.state, t), contains('turtle'));
    expect(e.state.battle!.slotsOpen, 4, reason: '화면 잠금 칸도 같은 기준');
  });
}
