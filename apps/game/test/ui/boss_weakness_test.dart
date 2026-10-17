import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/hud/buff_chips.dart';

import 'ui_harness.dart';

/// boss_fight 샘플의 보스를 [kind]로 바꾼다.
GameState _bossFight(String kind, {bool active = true}) {
  final s = loadFixture('boss_fight');
  final battle = s.battle!;
  return s.copyWith(
    battle: battle.copyWith(
      bossActive: active,
      enemies: [EnemyView(id: 1, kind: kind, x: 240, y: 90, hpRatio: 1, boss: true)],
    ),
  );
}

void main() {
  final tables = GameTables.load();

  test('보스 nameKey와 약점 계열 nameKey는 모두 문구가 있다 (table_text 연결)', () {
    for (final b in tables.regions.bosses.values) {
      expect(
        b.nameKey,
        anyOf(startsWith('battleBoss'), startsWith('econBoss')),
        reason: b.id,
      ); // 순환 보스 +18은 econ 문구(2026-10-18)
      for (final f in b.weakFamilies) {
        expect(tables.skills.byId(f).nameKey, isNotEmpty, reason: '${b.id}/$f');
      }
    }
  });

  // 사용자 2026-10-18 '전투 중 띠 아래 안내 줄이 보스를 가린다' — 보스전엔 약점 줄·알약(화물칸 가득·모두 강화 등)이 없다.
  // 약점은 보스 등장 이름표(BossIntro, 2초)가 보인다.
  testWidgets('보스전: 띠 아래 약점 줄·알약 없음(화물칸이 가득이어도)', (tester) async {
    final s = _bossFight('giant_hermit');
    final full = s.copyWith(wallet: s.wallet.copyWith(gold: goldCapacity(s, tables)));
    await pumpGame(tester, full, openTab: false);
    expect(find.byKey(const Key('boss.weak')), findsNothing);
    expect(find.byKey(const Key('cargo.full')), findsNothing);
  });

  testWidgets('보스전이 아니면 화물칸 가득 알약이 보인다', (tester) async {
    final s = _bossFight('giant_hermit', active: false);
    final full = s.copyWith(wallet: s.wallet.copyWith(gold: goldCapacity(s, tables)));
    await pumpGame(tester, full, openTab: false);
    expect(find.byKey(const Key('cargo.full')), findsOneWidget);
  });

  testWidgets('보스전: 광고 칩 줄은 오른쪽 끝 24dp 탭으로 접힘 · 누르면 펼침(S1 — 대보스와 겹침)', (tester) async {
    await pumpGame(
      tester,
      _bossFight('giant_hermit'),
      openTab: false,
      overrides: [adOfferProvider.overrideWith((ref, _) => true)],
    );
    expect(find.byKey(const Key('hud.buffChips')), findsNothing);
    final tab = tester.getRect(find.byKey(const Key('hud.buffChips.fold')));
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tab.right, closeTo(width, 0.5));
    expect(tab.width, buffFoldWidth);
    await tester.tap(find.byKey(const Key('hud.buffChips.fold')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('hud.buffChips')), findsOneWidget);
  });
}
