import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/hud/captain_skill_button.dart';

import 'ui_harness.dart';

// 선장 필살기 버튼 (사용자 '보스전도 밋밋하다' — S2 엔진 전 임시 어댑터): 오른쪽 아래 엄지 자리 큰 원, 게이지 채움,
// 가득이면 누를 수 있고 누르면 번쩍. 보스 도전 버튼은 그 왼쪽(겹치지 않게), 배 체력 막대와도 안 겹친다.

GameState _farming() {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(progress: s.progress.copyWith(farming: true));
}

void main() {
  testWidgets('가득: 누르면 사용 · 화면 번쩍 · 보스 도전·체력 막대와 안 겹침', (tester) async {
    var used = 0;
    await pumpGame(
      tester,
      _farming(),
      openTab: false,
      overrides: [
        captainSkillProvider.overrideWithValue((gauge: 1.0, ready: true)),
        captainSkillUseProvider.overrideWithValue(() => used++),
      ],
    );
    final skill = tester.getRect(find.byKey(const Key('captain.skill')));
    expect(skill.overlaps(tester.getRect(find.byKey(const Key('hud.shipHp')))), isFalse);
    expect(skill.overlaps(tester.getRect(find.byKey(const Key('boss.challenge')))), isFalse);
    await tester.tap(find.byKey(const Key('captain.skill')));
    await tester.pump();
    expect(used, 1);
    expect(find.byKey(const Key('captain.skill.flash')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('덜 찼으면 눌러도 안 쓴다 · 값이 없으면(계약 전 기본) 버튼 없음', (tester) async {
    var used = 0;
    await pumpGame(
      tester,
      _farming(),
      openTab: false,
      overrides: [
        captainSkillProvider.overrideWithValue((gauge: 0.4, ready: false)),
        captainSkillUseProvider.overrideWithValue(() => used++),
      ],
    );
    await tester.tap(find.byKey(const Key('captain.skill')));
    await tester.pump();
    expect(used, 0);
  });

  testWidgets('기본(계약 전)은 숨김', (tester) async {
    await pumpGame(tester, _farming(), openTab: false);
    expect(find.byKey(const Key('captain.skill')), findsNothing);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [
      ('360', Size(360, 640), 3.0),
      ('384', s24Size, s24Dpr),
      ('411', Size(411, 891), 2.625),
      ('tablet', Size(800, 1280), 2.0),
    ]) {
      testWidgets('필살기 가득 + 보스 도전 ko $name', (tester) async {
        await pumpGame(
          tester,
          _farming(),
          openTab: false,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          overrides: [captainSkillProvider.overrideWithValue((gauge: 1.0, ready: true))],
        );
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_captain_skill_$name.png'));
      });
    }
  });
}
