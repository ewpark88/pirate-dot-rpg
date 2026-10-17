import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-m3-meta 규칙 7~9, 수용 기준 10~13 (다음 목표·도감·튜토리얼).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState owning(int n) {
    final ids = [for (final c in t.crews.crews.take(n)) c.id];
    return h.newGame().copyWith(crews: {for (final id in ids) id: const CrewState()}, collection: ids.toSet());
  }

  test('기준 10: 도감 12명 → 공격 +6%, 다음 보너스 15명', () {
    final b = collectionBonus(owning(12), t);
    expect(b.owned, 12);
    expect(b.total, t.crews.crews.length);
    expect(b.attackBonus, closeTo(0.06, 1e-12));
    expect(b.nextAt, 15);
    expect(collectionBonus(owning(t.crews.crews.length), t).nextAt, isNull);
  });

  test('기준 11: 스테이지 27 → 다음 목표는 배 승급(30)까지 3', () {
    final s = owning(1).copyWith(
      progress: const Progress(stage: 27, bestStage: 27),
      ship: const ShipState(parts: {'cannon': 1, 'hull': 1, 'sail': 0, 'crowsnest': 0, 'cargo': 1}),
    );
    final g = nextGoal(s, t)!;
    expect(g.kind, GoalKind.shipTier);
    expect(g.remaining, 3);
    expect(g.progress, closeTo((27 - 1) / (30 - 1), 1e-9));
  });

  test('부위 도약이 더 가까우면 그것 (대포 milestoneEvery − 1 → 도약까지 1)', () {
    final m = t.shipParts.byId('cannon').milestoneEvery!;
    final s = owning(1).copyWith(
      progress: const Progress(stage: 2, bestStage: 2),
      ship: ShipState(parts: {'cannon': m - 1, 'hull': 0, 'sail': 0, 'crowsnest': 0, 'cargo': 0}),
    );
    final g = nextGoal(s, t)!;
    expect(g.kind, GoalKind.partMilestone);
    expect(g.id, 'cannon');
    expect(g.remaining, 1);
  });

  group('튜토리얼', () {
    GameState step(int n) => owning(1).copyWith(tutorialStep: n, battle: BattleView.empty);

    test('1·4·6은 TutorialAck, 6 다음은 끝(null) · 다른 단계 Ack는 무시', () {
      expect(sys.handle(step(1), const TutorialAck(1), h.ctx)!.tutorialStep, 2);
      expect(sys.handle(step(4), const TutorialAck(5), h.ctx)!.tutorialStep, 4);
      expect(sys.handle(step(4), const TutorialAck(4), h.ctx)!.tutorialStep, 5);
      expect(sys.handle(step(6), const TutorialAck(6), h.ctx)!.tutorialStep, isNull);
      expect(sys.handle(step(2), const TutorialAck(2), h.ctx)!.tutorialStep, 2);
    });

    test('기준 12: 2 → 대포 Lv3이면 3, 3 → 스테이지 3 보스 처치(bestStage 4)면 4, 5 → 일괄 합치기면 6', () {
      final s2 = step(2).copyWith(ship: const ShipState().withLevel('cannon', 3));
      expect(sys.update(s2, h.ctx).tutorialStep, 3);
      expect(sys.update(step(2), h.ctx).tutorialStep, 2);
      final s3 = step(3).copyWith(progress: const Progress(stage: 4, bestStage: 4));
      expect(sys.update(s3, h.ctx).tutorialStep, 4);
      expect(sys.update(step(3).copyWith(progress: const Progress(stage: 3, bestStage: 3)), h.ctx).tutorialStep, 3);
      expect(sys.handle(step(5), const MergeAllCards(), h.ctx)!.tutorialStep, 6);
    });

    test('환영 선원(피드백 #21): 첫 강화 단계를 넘는 틱에 bones 희귀 1명 + 빈 출전 칸 + CardGranted(starter), 한 번만', () {
      final w = t.meta.raw.obj('tutorial').obj('welcomeCrew');
      final id = w.str('crewId');
      final s2 = h.newGame().copyWith(tutorialStep: 2, ship: const ShipState().withLevel('cannon', 3));
      final s = sys.update(s2, h.ctx);
      expect(s.crews[id]!.level, t.rarities.byId(w.str('rarity')).levelMin);
      expect(s.fleet, contains(id));
      final got = h.of<CardGranted>().single;
      expect((got.crewId, got.rarity, got.source, got.isNew), (id, w.str('rarity'), 'starter', true));
      expect(t.crews.byId(id).family, 'direct', reason: '연사(직사) 계열');
      expect(sys.update(s.copyWith(tutorialStep: 2), h.ctx).crews[id], s.crews[id], reason: '이미 있으면 안 준다');
    });

    test('건너뛰기도 환영 선원을 그 틱에 준다(첫 강화 전이면) · 이미 넘었으면 다시 안 준다', () {
      final id = t.meta.raw.obj('tutorial').obj('welcomeCrew').str('crewId');
      final s = sys.handle(h.newGame().copyWith(tutorialStep: 1), const SkipTutorial(), h.ctx)!;
      expect(s.tutorialStep, isNull);
      expect(s.crews, contains(id));
      expect(
        sys.handle(h.newGame().copyWith(tutorialStep: 4), const SkipTutorial(), h.ctx)!.crews,
        isNot(contains(id)),
      );
    });

    test('기준 13: SkipTutorial → null · OpSetTutorial은 그대로 설정', () {
      expect(sys.handle(step(1), const SkipTutorial(), h.ctx)!.tutorialStep, isNull);
      expect(sys.handle(step(1), const OpSetTutorial(5), h.ctx)!.tutorialStep, 5);
      expect(sys.handle(step(1), const OpSetTutorial(null), h.ctx)!.tutorialStep, isNull);
    });
  });
}
