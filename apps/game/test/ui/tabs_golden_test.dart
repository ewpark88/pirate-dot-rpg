import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

/// 기준 9: 영어 골든 4장 (영어 문구가 한국어보다 30~40% 길어 잘림을 보기 좋다).
/// HUD와 탭 패널만 본다 — 전장은 ui_harness가 빈 상자로 바꾼다 (전장 골든은 render 레인 몫).
/// 이미지는 test/goldens/에 있고, 사람이 `flutter test --update-goldens`로만 갱신한다.
/// 글꼴은 SDK의 Roboto (loadGoldenFonts). 골든은 Windows에서 만들었다 — 다른 OS는 글자 렌더가 조금 다를 수 있다.
void main() {
  setUpAll(loadGoldenFonts);

  for (final (name, fixture, tab) in [
    ('en_ship_stage37', 'stage37_midgame', shipTab),
    ('en_summon_stage37', 'stage37_midgame', summonTab),
    ('en_crew_stage37', 'stage37_midgame', crewTab),
    ('en_hud_boss_fight', 'boss_fight', shipTab),
  ]) {
    testWidgets('골든: $name', (tester) async {
      await pumpGame(tester, loadFixture(fixture), tab: tab);
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/$name.png'));
    });
  }
}
