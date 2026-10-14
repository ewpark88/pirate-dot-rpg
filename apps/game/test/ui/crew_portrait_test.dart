import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';

import 'ui_harness.dart';

void main() {
  test('crews.json의 초상 40장이 모두 에셋에 있다 (도트 팩 v0.2)', () {
    for (final c in GameTables.load().crews.crews) {
      expect(File('assets/${c.portrait}').existsSync(), isTrue, reason: c.portrait);
    }
  });

  testWidgets('선원 탭: 40명 모두 초상', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab);
    expect(find.byType(CrewPortrait, skipOffstage: false), findsNWidgets(40));
  });
}
