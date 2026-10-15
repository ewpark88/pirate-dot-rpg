import 'dart:convert';

import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 경제 테이블이 설계서 4.3 · 4.3.3 값과 같은지 (스펙 결정 ③).
void main() {
  final t = GameTables.load();

  test('소환 확률 65/27/7/1, 신화 없음, 50회 천장 영웅 이상', () {
    expect(
      {for (final r in t.rarities.rarities) r.id: r.summonRate},
      {
        'common': 0.65,
        'rare': 0.27,
        'hero': 0.07,
        'legend': 0.01,
        'mythic': 0.0,
      },
    );
    expect(t.rarities.pityCount, 50);
    expect(t.rarities.pityMinRarity, 'hero');
  });

  test('젬 광고 = 30젬 = 소환 1회 (사용자 결정 2026-10-14)', () {
    final chest = t.ads.placements.firstWhere((p) => p.id == 'chest').reward;
    expect(chest.integer('altGems'), t.meta.summonCostGems);
  });

  test('오프라인 가득 알림은 하루 1회, 2회는 검증 실패 (피로 금지 규칙, platform 요청 meta-notify)', () {
    expect(t.meta.notificationsDailyMax, 1);
    final m = jsonDecode(rawTables['meta']!) as Map<String, dynamic>;
    (m['notifications'] as Map)['dailyMax'] = 2;
    expect(
      () => GameTables.load({...rawTables, 'meta': jsonEncode(m)}),
      throwsA(isA<TableValidationException>().having((e) => e.errors.join(), 'errors', contains('dailyMax'))),
    );
  });

  test('오프라인 효율 계수는 0~1', () {
    expect(t.meta.offlineEfficiency, inExclusiveRange(0, 1));
  });

  test('보스 드롭 카드 등급 80/17/2.8/0.2', () {
    expect(t.rarities.bossDropRates, {'common': 0.8, 'rare': 0.17, 'hero': 0.028, 'legend': 0.002});
  });

  test('레벨 1 올리는 경험치는 등급별 1·3·8·20·30', () {
    // 영웅 6 → 8: 하루 40분 sim으로 ‘승급으로 만든 첫 전설 4~8일’에 맞춤 (사용자 결정 B, 2026-10-14)
    expect(t.growth.expToNext, {'common': 1, 'rare': 3, 'hero': 8, 'legend': 20, 'mythic': 30});
  });

  test('승급: 카드 3·6·10·20, 증표는 신화만 50, 골드는 처치 골드 × 100·300·1000·3000', () {
    expect([for (final p in t.growth.promotions) p.cards], [3, 6, 10, 20]);
    expect([for (final p in t.growth.promotions) p.tokens], [0, 0, 0, 50]);
    expect([for (final p in t.growth.promotions) p.goldKills], [100, 300, 1000, 3000]);
  });

  test('보스 카드: 스테이지 1~10은 2장, 이후 1 + floor(stage/150), 처음 14장은 옥토(사용자 결정 2026-10-14)', () {
    final b = t.growth.bossCards;
    expect(b.countAt(1), 2);
    expect(b.countAt(10), 2);
    expect(b.countAt(11), 1);
    expect(b.countAt(149), 1);
    expect(b.countAt(150), 2);
    expect(b.countAt(300), 3);
    expect(b.starterCrew, 'octo');
    expect(b.starterCount, 14);
    expect(b.starterEvery, greaterThanOrEqualTo(1));
  });

  test('반복 보스 카드: 짝수 스테이지에서만 1장 (환생 3, 사용자 결정 2026-10-15)', () {
    final b = t.growth.bossCards;
    expect([b.repeatEvery, b.repeatCount], [2, 1]);
    expect(
      [
        for (final s in [1, 2, 3, 10, 11, 150]) b.repeatCountAt(s),
      ],
      [0, 1, 0, 1, 0, 1],
    );
  });
}
