import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/preview/crew_preview_view.dart';
import 'package:pirate_dot/ui/crew/crew_preview.dart';

import 'ui_harness.dart';

/// 선원 상세 공격 미리보기(S1 2026-10-17): 등급 탭 → 그 등급 첫 레벨로 다시, 창을 닫으면 미리보기도 사라진다(멈춤).
void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('등급 탭: 지금 · 다음 · 전설 · 신화, 누르면 그 등급 첫 레벨 장면 / 닫으면 사라짐', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab);
    final card = find.byKey(const Key('crew.card.octo'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(of: find.byKey(const Key('sheet.panel')), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
    final view = find.byType(CrewPreviewView);
    expect(view, findsOneWidget);
    final before = tester.widget<CrewPreviewView>(view).level;
    expect(find.byKey(const Key('crew.preview.tab.legend')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('crew.preview.tab.mythic')));
    await tester.tap(find.byKey(const Key('crew.preview.tab.mythic')));
    await tester.pumpAndSettle();
    expect(tester.widget<CrewPreviewView>(view).level, greaterThan(before));
    await tester.tapAt(const Offset(4, 4)); // 창 밖 = 닫기
    await tester.pumpAndSettle();
    expect(find.byType(CrewPreviewPanel), findsNothing);
  });
}
