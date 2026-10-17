import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/hud/boss_bars.dart';

import 'ui_harness.dart';

// 보스 체력 여러 줄 (S2 bossBarsLeft 전 임시 어댑터): '×남은 줄' · 줄마다 색 · 마지막 줄은 기존 막대(빨강, ×없음).

void main() {
  testWidgets('3줄 중 2번째: 글에 ×2 · 마지막 줄이면 ×없음', (tester) async {
    await pumpGame(
      tester,
      loadFixture('boss_fight'),
      openTab: false,
      overrides: [bossBarsProvider.overrideWithValue((left: 2, total: 3, ratio: 0.5))],
    );
    final text = tester.widget<Text>(find.byKey(const Key('hud.bossHp.text'))).data!;
    expect(text, endsWith('×2'));
  });

  testWidgets('운영자 가짜: 전체 0.5 → 3줄 중 2번째 줄 절반', (tester) async {
    final c = await pumpGame(tester, loadFixture('boss_fight'), openTab: false);
    expect(c, isNotNull);
    expect(bossBarColor(3), isNot(bossBarColor(2)));
    expect(bossBarColor(1), const Color(0xFFE8443A));
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [
      ('360', Size(360, 640), 3.0),
      ('384', s24Size, s24Dpr),
      ('411', Size(411, 891), 2.625),
      ('tablet', Size(800, 1280), 2.0),
    ]) {
      testWidgets('보스 3줄 중 2번째 ko $name', (tester) async {
        await pumpGame(
          tester,
          loadFixture('boss_fight'),
          openTab: false,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          overrides: [bossBarsProvider.overrideWithValue((left: 2, total: 3, ratio: 0.4))],
        );
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_bars_$name.png'));
      });
    }
  });
}
