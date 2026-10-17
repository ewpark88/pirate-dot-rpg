import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/crew/crew_damage_line.dart';

import 'ui_harness.dart';

/// 선원 상세 피해 줄(#13): 이번 스테이지 피해(BattleView.crewDamage) + 지난 보스 피해와 몫(%).
void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('이번 스테이지 피해 · 지난 보스 피해(%) — 없으면 안 그림', (tester) async {
    final base = loadFixture('stage37_midgame');
    final s = base.copyWith(
      battle: BattleView.fromJson({
        ...base.battle!.toJson(),
        'crewDamage': {'octo': BigNum.from(12000).toJson()},
      }),
    );
    await pumpGame(tester, s, tab: crewTab);
    final card = find.byKey(const Key('crew.card.octo'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(of: find.byKey(const Key('sheet.panel')), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
    final line = find.byKey(const Key('crew.damage.octo'));
    Finder inLine(String text) => find.descendant(of: line, matching: find.textContaining(text));
    expect(line, findsOneWidget);
    expect(inLine('12K'), findsWidgets);
    expect(inLine('%'), findsNothing, reason: '보스 처치 전엔 보스 피해 없음');
    // 보스 처치 창이 채우는 것과 같은 값.
    ProviderScope.containerOf(tester.element(card)).read(lastBossDamageProvider.notifier).value = {
      'octo': BigNum.from(300),
      'pang': BigNum.from(700),
    };
    await tester.pumpAndSettle();
    expect(inLine('30%'), findsWidgets);
  });
}
