import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/skin/reward_sparkle.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/badge_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 스킨 r2 (docs/specs/ui-skin-r2.md, S1 결정: 빛 줄기 5초 · 주 버튼만 '톡' · 숫자 뱃지는 선원·퀘스트).

class _Audio implements AudioPort {
  final played = <(String, double)>[];

  @override
  void playSfx(String id, {int variant = 0, double pitch = 1}) => played.add((id, pitch));

  @override
  void playBgm(String id) {}

  @override
  void stopBgm() {}

  @override
  void setVolumes({required double sfx, required double bgm}) {}
}

Widget _app(Widget child, {List<Override> overrides = const []}) => ProviderScope(
  overrides: [initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame')), ...overrides],
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('선원 도크 아이콘: 할 일 수를 숫자 뱃지로', (tester) async {
    await pumpGame(
      tester,
      loadFixture('stage37_midgame'),
      openTab: false,
      overrides: [
        crewBadgeCountProvider.overrideWithValue(3),
      ],
    );
    expect(find.descendant(of: find.byKey(const Key('tab.dot.2')), matching: find.text('3')), findsOneWidget);
    // 배 아이콘은 점만 (숫자 없음).
    expect(find.descendant(of: find.byKey(const Key('tab.dot.1')), matching: find.byType(Text)), findsNothing);
  });

  testWidgets("누르면 '톡' — 파랑·금색만, 흰 버튼은 소리 없음", (tester) async {
    final audio = _Audio();
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkinButton(key: const Key('p'), onPressed: () {}, child: const Text('P')),
            SkinButton(key: const Key('g'), tone: SkinTone.gold, onPressed: () {}, child: const Text('G')),
            SkinButton(key: const Key('w'), tone: SkinTone.plain, onPressed: () {}, child: const Text('W')),
          ],
        ),
        overrides: [audioPortProvider.overrideWithValue(audio)],
      ),
    );
    for (final k in ['p', 'g', 'w']) {
      await tester.tap(find.byKey(Key(k)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(audio.played, [('pop', 1.6), ('pop', 1.6)]);
  });

  testWidgets('금색 버튼 빛 줄기: 5초마다 한 번 지나가고 끝난다 · 절전이면 없음', (tester) async {
    // 샘플은 절전 켜짐 — 먼저 끈 상태로.
    final s = loadFixture('stage37_midgame');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialGameStateProvider.overrideWithValue(s.copyWith(settings: s.settings.withValue('powerSave', false))),
        ],
        child: MaterialApp(
          home: Center(
            child: SkinButton(tone: SkinTone.gold, onPressed: () {}, child: const Text('G')),
          ),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          initialGameStateProvider.overrideWithValue(s.copyWith(settings: s.settings.withValue('powerSave', true))),
        ],
        child: MaterialApp(
          home: Center(
            child: SkinButton(tone: SkinTone.gold, onPressed: () {}, child: const Text('G')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('보상 반짝임은 0.8초 뒤 끝난다', (tester) async {
    await tester.pumpWidget(_app(const RewardSparkle(child: Text('+50'))));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
