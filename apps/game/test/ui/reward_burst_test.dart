import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/widgets/reward_burst.dart';

import 'ui_harness.dart';

/// 보상 터짐(디자인 개편 ③): 단계(0.1 흔들림 · 0.4 열려 솟음 · 1 정렬, 7개 = 2줄) 4기기 + 등급 빛 5색(s24, 상자·도감 책).
const List<RewardItem> _items = [
  (icon: UiSprites.coin, label: '52K', tier: RewardTier.gold),
  (icon: UiSprites.gem, label: '30', tier: RewardTier.blue),
  (icon: UiSprites.shard, label: '3', tier: RewardTier.purple),
  (icon: UiSprites.tabSummon, label: '1', tier: RewardTier.purple),
  (icon: UiSprites.star, label: '2', tier: RewardTier.green),
  (icon: UiSprites.tailwind, label: '1', tier: RewardTier.blue),
  (icon: UiSprites.coin, label: '1.2M', tier: RewardTier.gold),
];

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', Size(384, 832), 2.8125),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

Widget _panel(Widget child) => Expanded(
  child: ColoredBox(
    color: const Color(0xFF241E46),
    child: ClipRect(child: child),
  ),
);

Future<void> _pump(WidgetTester tester, Size size, double dpr, List<Widget> panels) async {
  tester.view
    ..physicalSize = Size(size.width * panels.length, size.height) * dpr
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Row(children: [for (final p in panels) _panel(p)]),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

void main() {
  setUpAll(loadGoldenFonts);

  for (final (name, size, dpr) in _devices) {
    testWidgets('보상 터짐 단계 $name', (tester) async {
      await _pump(tester, size, dpr, [
        for (final t in const [0.1, 0.4, 1.0])
          RewardBurst(items: _items, source: UiSprites.chest, openedSource: UiSprites.chestOpen, progress: t),
      ]);
      expect(find.byKey(const Key('reward.item.6')), findsNWidgets(3));
      await expectLater(find.byType(Row).first, matchesGoldenFile('../goldens/ko_reward_burst_$name.png'));
    });
  }

  testWidgets('보상 터짐 등급 빛 5색 s24', (tester) async {
    await _pump(tester, _devices[1].$2, _devices[1].$3, [
      for (final tier in RewardTier.values)
        RewardBurst(items: _items.take(3).toList(), source: UiSprites.book, tier: tier, progress: 1),
    ]);
    await expectLater(find.byType(Row).first, matchesGoldenFile('../goldens/ko_reward_burst_tiers.png'));
  });

  testWidgets('움직이는 터짐은 1.8초 뒤 멈추고, lite는 빛줄기를 줄인다', (tester) async {
    await _pump(tester, _devices[1].$2, _devices[1].$3, [const RewardBurst(items: _items, source: UiSprites.chest, lite: true)]);
    await tester.pump(RewardBurst.duration);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reward.item.0')), findsOneWidget);
  });
}
