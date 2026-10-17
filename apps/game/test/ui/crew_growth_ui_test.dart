import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'ui_harness.dart';

// 선원 레벨업 이유(#12)·합치기 표시(#11·#16): 일괄 합치기 56dp·'n명', 카드 '↑ +n', 상세 '레벨업하면 공격력'·합치기 버튼.

/// 새우팡(pang)에 경험치를 채워 합칠 수 있게(crew_filter_test와 같은 방법).
GameState _mergeable() {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(crews: {...s.crews, 'pang': s.crews['pang']!.copyWith(exp: 9999)});
}

void main() {
  Finder upBadge() => find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('crew.up.'),
  );

  testWidgets('일괄 합치기는 48dp 이상(선원 탭 머리 한 줄 — 실기기 2026-10-17)에 합칠 선원 수, 합칠 수 있는 카드엔 ↑ +n 배지', (tester) async {
    await pumpGame(tester, _mergeable(), tab: crewTab);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('crew.mergeAll'))).height, greaterThanOrEqualTo(48));
    expect(find.textContaining('Merge all · '), findsOneWidget);
    // 도감 카드(수집 보상 줄)가 위에 있어 격자는 굴려서 본다.
    await tester.scrollUntilVisible(
      find.byKey(const Key('crew.card.pang')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(upBadge(), findsWidgets);
  });

  testWidgets('상세: 레벨업 이유 줄 + 합칠 수 있으면 합치기 버튼 → MergeAllCards', (tester) async {
    final log = await pumpGame(tester, _mergeable(), tab: crewTab);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('crew.card.pang')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('crew.card.pang')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crew.detail.why')), findsOneWidget);
    expect(find.byKey(const Key('crew.detail.why.level')), findsOneWidget);
    expect(find.textContaining('Level up: attack +'), findsOneWidget);
    final merge = find.byKey(const Key('crew.detail.merge.pang'));
    await tester.ensureVisible(merge);
    await tester.pumpAndSettle();
    expect(tester.getSize(merge).height, greaterThanOrEqualTo(48));
    await tester.tap(merge);
    expect(log.sent.whereType<MergeAllCards>().single.crewId, 'pang', reason: '이 선원만');
  });
}
