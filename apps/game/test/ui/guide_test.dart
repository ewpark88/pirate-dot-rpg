import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 가이드 v2 처음 만나는 시스템 카드 (docs/specs/ui-guide-v2.md 5절, S1 결정 9절): 튜토리얼 뒤 각 1회 · 한 번에 하나 ·
// 띄우는 순간 MarkHint · 누름을 막지 않음 · 전투 카드는 어둡게 하지 않고 3초 뒤 알약 · 설정 '안내 다시 보기' = ClearHints('guide.').

final _t = GameTables.load();

/// [seen]을 본 기록으로 둔 상태.
GameState _seen(GameState s, Iterable<String> seen) => s.copyWith(
  settings: Settings.fromJson({
    ...s.settings.toJson(),
    'battleView': s.settings.battleView,
    'hints': [...seen],
  }),
);

/// 튜토리얼이 끝난 stage37 + 화물칸 가득 + 젬 넉넉 → 화물칸·소환 카드 조건이 맞는다.
GameState _two() {
  final s = loadFixture('stage37_midgame').copyWith(clearTutorial: true);
  return s.copyWith(wallet: s.wallet.copyWith(gold: goldCapacity(s, _t), gems: 100000));
}

void main() {
  testWidgets('조건이 맞는 첫 카드 하나 → MarkHint, 알겠어요 → 다음 카드(줄 서기), 둘이 동시에 뜨지 않는다', (tester) async {
    final s = _two();
    final active = activeGuides(s, _t).where((id) => !battleGuideIds.contains(id)).toList();
    expect(active.length, greaterThanOrEqualTo(2), reason: '샘플에 조건 맞는 카드가 둘 이상 있어야 줄 서기를 본다');
    final log = await pumpGame(tester, _seen(s, battleGuideIds), openTab: false, guides: true);
    await tester.pump();
    expect(find.byKey(const Key('guide.card')), findsOneWidget);
    expect(log.hints.map((c) => c.id), [active.first]);
    await tester.tap(find.byKey(const Key('guide.ok')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('guide.card')), findsOneWidget);
    expect(log.hints.map((c) => c.id), active.take(2));
  });

  testWidgets('본 기록(hints)에 있으면 안 뜬다 · 튜토리얼 중엔 시스템 카드 없음', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
    expect(find.byKey(const Key('guide.card')), findsNothing);
    final log = await pumpGame(
      tester,
      _seen(loadFixture('stage37_midgame').copyWith(tutorialStep: 2), const []),
      openTab: false,
      keepTutorial: true,
      guides: true,
    );
    await tester.pump();
    expect(log.hints, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('건너뛰기 → 끄기: 남은 시스템 카드를 모두 본 것으로(MarkHint 전부), 카드 없음', (tester) async {
    final log = await pumpGame(tester, _seen(_two(), const []), openTab: false, guides: true);
    await tester.pump();
    await tester.tap(find.byKey(const Key('guide.skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide.skip.off')));
    await tester.pumpAndSettle();
    expect(log.hints.map((c) => c.id).toSet(), guideIds.toSet());
    expect(find.byKey(const Key('guide.card')), findsNothing);
  });

  testWidgets('보스전 카드: 어둡게 하지 않고 3초 뒤 오른쪽 위 알약, 누르면 다시 펼침', (tester) async {
    final s = loadFixture('boss_fight').copyWith(clearTutorial: true);
    await pumpGame(tester, _seen(s, guideIds.where((id) => id != 'guide.boss')), openTab: false, guides: true);
    await tester.pump();
    expect(find.text('Boss fight'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('guide.card')), findsNothing);
    expect(find.byKey(const Key('guide.pill')), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide.pill')));
    await tester.pump();
    expect(find.byKey(const Key('guide.card')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('보스전이 끝나면 보스 카드는 닫힌다', (tester) async {
    final s = loadFixture('boss_fight').copyWith(clearTutorial: true);
    final seen = _seen(s, guideIds.where((id) => id != 'guide.boss'));
    await pumpGame(tester, seen, openTab: false, guides: true);
    await tester.pump();
    expect(find.byKey(const Key('guide.card')), findsOneWidget);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    c.read(gameStateProvider.notifier).replace(seen.copyWith(battle: seen.battle!.copyWith(bossActive: false)));
    await tester.pump();
    expect(find.byKey(const Key('guide.card')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets("설정 '안내 다시 보기' → ClearHints('guide.')", (tester) async {
    final log = await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
    await tester.tap(find.byKey(const Key('hud.settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('settings.guideReplay')), 100);
    await tester.tap(find.byKey(const Key('settings.guideReplay')));
    expect(log.sent.whereType<ClearHints>().map((c) => c.prefix), ['guide.']);
    await tester.pump(const Duration(seconds: 5));
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);
    const devices = [
      ('360', Size(360, 640), 3.0),
      ('s24', s24Size, s24Dpr),
      ('411', Size(411, 891), 2.625),
      ('tablet', Size(800, 1280), 2.0),
    ];
    for (final (name, size, dpr) in devices) {
      testWidgets('2단계 카드 $name', (tester) async {
        await pumpGame(
          tester,
          loadFixture('stage37_midgame').copyWith(tutorialStep: 2),
          keepTutorial: true,
          openTab: false,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
        );
        await tester.pump(const Duration(seconds: 3));
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_guide_step2_$name.png'));
      });
      testWidgets('보스전 카드 $name', (tester) async {
        final s = loadFixture('boss_fight').copyWith(clearTutorial: true);
        await pumpGame(
          tester,
          _seen(s, guideIds.where((id) => id != 'guide.boss')),
          openTab: false,
          guides: true,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_guide_boss_$name.png'));
        await tester.pump(const Duration(seconds: 4));
      });
    }
    testWidgets('영어 2단계 카드 s24', (tester) async {
      await pumpGame(
        tester,
        loadFixture('stage37_midgame').copyWith(tutorialStep: 2),
        keepTutorial: true,
        openTab: false,
      );
      await tester.pump(const Duration(seconds: 3));
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_guide_step2_s24.png'));
    });
  });
}
