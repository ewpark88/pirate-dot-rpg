import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/guide/guide_moments.dart';
import 'package:pirate_dot/ui/home_screen.dart';

import 'ui_harness.dart';

// 오늘 생긴 기능 첫 안내 (S1 2026-10-18): 대군 습격·2배속은 순간(8초), 업적은 받을 것이 생기면 — 한 실행에 하나.
// 설정 '도움말'은 새 시스템 7칸, 누르면 펼친다.

GameState _seen(GameState s, Iterable<String> seen) => s.copyWith(
  settings: Settings.fromJson({
    ...s.settings.toJson(),
    'battleView': s.settings.battleView,
    'hints': [...seen],
  }),
);

Future<ProviderContainer> _pump(WidgetTester tester, {Set<String> except = const {}}) async {
  final s = loadFixture('stage37_midgame').copyWith(clearTutorial: true);
  await pumpGame(tester, _seen(s, guideIds.where((id) => !except.contains(id))), openTab: false, guides: true);
  return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

void main() {
  testWidgets('대군 습격 순간 → 옥토 "몰려와요!", 8초 뒤 닫힘', (tester) async {
    final c = await _pump(tester, except: {'guide.horde', 'guide.speed'});
    c.read(guideMomentsProvider.notifier).flash('guide.horde');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.textContaining('Here they come'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(find.textContaining('Here they come'), findsNothing);
  });

  testWidgets('새 기능 안내는 한 실행에 하나: 대군 습격을 봤으면 2배속은 다음 실행에', (tester) async {
    final c = await _pump(tester, except: {'guide.horde', 'guide.speed'});
    c.read(guideMomentsProvider.notifier).flash('guide.horde', duration: const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    c.read(guideMomentsProvider.notifier).flash('guide.speed');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));
    expect(c.read(guideQueueProvider), isNull);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('설정 도움말: 7칸, 피버를 누르면 설명이 펼쳐짐', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    await tester.tap(find.byKey(const Key('hud.settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('help.fever')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    for (final id in ['tower', 'rush', 'dungeon', 'achievements', 'pass', 'ultimate', 'fever']) {
      expect(find.byKey(Key('help.$id'), skipOffstage: false), findsOneWidget);
    }
    expect(find.textContaining('fever gauge'), findsNothing);
    // 맨 아래 칸이 화면 끝에 걸리지 않게 조금 더 올린 뒤 누른다.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fever').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('fever gauge'), findsOneWidget);
  });
}
