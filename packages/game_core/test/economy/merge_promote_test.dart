import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-m1 수용 기준 9~10 (일괄 합치기·승급).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState withCrews(Map<String, CrewState> crews, {num gold = 0, int tokens = 0}) =>
      h.newGame(gold: BigNum.from(gold)).copyWith(crews: crews, tokens: tokens);

  test('기준 9: 적립 경험치가 충분해도 승급 문(Lv15)에서 멈추고 남는 경험치·장수는 보존', () {
    final s0 = withCrews({'octo': const CrewState(exp: 100, cards: 7)});
    final s = sys.handle(s0, const MergeAllCards(), h.ctx)!;
    final c = s.crews['octo']!;
    expect(c.level, 15);
    expect(c.exp, 100 - 14 * t.growth.expToNext['common']!);
    expect(c.cards, 7);
    expect(h.of<SaveRequested>(), hasLength(1));
  });

  test('crewId를 주면 그 해적만 합친다(선원 상세 지금 합치기, S4 발견 2026-10-17)', () {
    final s0 = withCrews({'octo': const CrewState(exp: 5), 'turtle': const CrewState(exp: 5)});
    final s = sys.handle(s0, const MergeAllCards(crewId: 'octo'), h.ctx)!;
    expect(s.crews['octo']!.level, greaterThan(1));
    expect(s.crews['turtle'], s0.crews['turtle']);
    expect(
      Command.fromJson(const MergeAllCards(crewId: 'octo').toJson()),
      isA<MergeAllCards>().having((c) => c.crewId, 'crewId', 'octo'),
    );
    expect(const MergeAllCards().toJson().keys, isNot(contains('crewId')));
  });

  test('canMergeAny: 일괄 합치기로 레벨이 오르는 선원이 있을 때만 true (UI 선원 탭 빨간 점, S4 요청)', () {
    expect(canMergeAny(withCrews({'octo': const CrewState()}), t), isFalse);
    expect(canMergeAny(withCrews({'octo': const CrewState(), 'turtle': const CrewState(exp: 1)}), t), isTrue);
    // 승급 문(일반 Lv15)에서는 경험치가 남아도 합치기로 오르지 않는다
    expect(canMergeAny(withCrews({'octo': const CrewState(level: 15, exp: 50)}), t), isFalse);
    // 희귀는 3 필요
    expect(canMergeAny(withCrews({'octo': const CrewState(level: 16, exp: 2)}), t), isFalse);
    expect(canMergeAny(withCrews({'octo': const CrewState(level: 16, exp: 3)}), t), isTrue);
    // MergeAllCards와 같은 판정
    for (final c in const [CrewState(exp: 1), CrewState(level: 15, exp: 9), CrewState(level: 16, exp: 3)]) {
      final s0 = withCrews({'octo': c});
      final merged = sys.handle(s0, const MergeAllCards(), EconomyHarness().ctx)!;
      expect(canMergeAny(s0, t), merged.crews['octo']!.level != c.level);
    }
  });

  test('합치기는 등급별 경험치(희귀 3)로 레벨을 올린다, 모든 선원 한 번에', () {
    final s0 = withCrews({'octo': const CrewState(level: 16, exp: 7), 'turtle': const CrewState(exp: 2)});
    final s = sys.handle(s0, const MergeAllCards(), h.ctx)!;
    expect(s.crews['octo']!.level, 18);
    expect(s.crews['octo']!.exp, 1);
    expect(s.crews['turtle']!.level, 3);
    expect(s.crews['turtle']!.exp, 0);
  });

  test('합칠 것이 없으면 상태·이벤트 변화 없음', () {
    final s0 = withCrews({'octo': const CrewState(level: 15, exp: 50)});
    final s = sys.handle(s0, const MergeAllCards(), h.ctx)!;
    expect(s.crews['octo']!.level, 15);
    expect(h.events, isEmpty);
  });

  test('기준 10: Lv15 + 카드 3장 + 골드 → 승급하면 Lv16, 카드·골드 차감, 파워 ×1.35 계단', () {
    final gold = promotionGold(t, nextPromotion(t, 15)!, 1);
    final s0 = withCrews({'octo': const CrewState(level: 15, exp: 4, cards: 5)}, gold: gold.toDouble() + 10);
    final s = sys.handle(s0, const PromoteCrew('octo'), h.ctx)!;
    final c = s.crews['octo']!;
    expect(c.level, 16);
    expect(c.cards, 2);
    expect(c.exp, 4);
    expect(s.wallet.gold.closeTo(BigNum.from(10), relTol: 1e-6), isTrue);
    expect(promotionCount(t.rarities, c.level), 1);
    final e = h.of<CrewPromoted>().single;
    expect((e.crewId, e.rarity), ('octo', 'rare'));
    expect(h.of<SaveRequested>(), hasLength(1));
  });

  test('신화 승급은 증표 50도 쓴다', () {
    final s0 = withCrews({'octo': const CrewState(level: 60, cards: 20)}, gold: 1e60, tokens: 55);
    final s = sys.handle(s0, const PromoteCrew('octo'), h.ctx)!;
    expect(s.crews['octo']!.level, 61);
    expect(s.tokens, 5);
  });

  test('조건이 모자라면 승급하지 않는다', () {
    final s0 = withCrews({'octo': const CrewState(level: 15, cards: 2)}, gold: 1e30);
    final s = sys.handle(s0, const PromoteCrew('octo'), h.ctx)!;
    expect(s.crews['octo']!.level, 15);
    expect(h.events, isEmpty);
  });
}
