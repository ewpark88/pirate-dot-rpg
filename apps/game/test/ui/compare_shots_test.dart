import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

/// 기준 gif(320×180 ×2)와 나란히 볼 ×2 화면 찍기 (스펙 ui-quality-v1 기준 3, 사람 확인용).
/// 골든이 아니다 — `UI_COMPARE=1 flutter test test/ui/compare_shots_test.dart --update-goldens`로만 찍고, 평소엔 건너뛴다.
/// 400dp × dpr 2 = 실제 800px → 도트 한 칸 = 2px (기준 gif와 같은 배율).
void main() {
  final enabled = Platform.environment['UI_COMPARE'] == '1';
  setUpAll(loadGoldenFonts);

  for (final (name, tab) in [('ship', shipTab), ('crew', crewTab), ('summon', summonTab), ('voyage', voyageTab)]) {
    testWidgets('×2 화면: $name', skip: !enabled, (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), tab: tab, dpr: 2);
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../../../docs/specs/ui-quality-v1/x2_$name.png'),
      );
    });
  }
}
