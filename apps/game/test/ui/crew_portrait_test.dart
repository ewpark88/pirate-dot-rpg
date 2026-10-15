import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';

import 'ui_harness.dart';

void main() {
  test('crews.json의 초상 40장이 모두 에셋에 있다 (도트 팩 v0.2)', () {
    for (final c in GameTables.load().crews.crews) {
      expect(File('assets/${c.portrait}').existsSync(), isTrue, reason: c.portrait);
    }
  });

  test('PB 카드 그림: 40명 일러스트·얼굴 초상과 등급 테두리 5종이 에셋에 있다', () {
    for (final c in GameTables.load().crews.crews) {
      expect(File(pbCharacter(c.id)).existsSync(), isTrue, reason: c.id);
      expect(File(pbPortrait(c.id)).existsSync(), isTrue, reason: c.id);
    }
    for (final r in GameTables.load().rarities.rarities) {
      expect(File(pbCardBack(r.id)).existsSync(), isTrue, reason: r.id);
      expect(File(pbCardFront(r.id)).existsSync(), isTrue, reason: r.id);
    }
  });

  testWidgets('선원 탭: 40명 모두 PB 카드', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab);
    expect(find.byType(PbCardFront, skipOffstage: false), findsNWidgets(40));
  });
}
