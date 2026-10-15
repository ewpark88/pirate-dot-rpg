import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'ui_harness.dart';

/// 소환 연출 단계별 프레임 (사람 확인용, 골든 아님): `UI_COMPARE=1 flutter test test/ui/summon_frames_test.dart --update-goldens`.
/// 결과는 docs/specs/ui-summon-v2/frame_<단계>.png (S24).
const _ten = [
  SummonResult(crewId: 'octo', rarity: 'common', isNew: true),
  SummonResult(crewId: 'starry', rarity: 'common'),
  SummonResult(crewId: 'pang', rarity: 'rare'),
  SummonResult(crewId: 'pingu', rarity: 'common'),
  SummonResult(crewId: 'manta', rarity: 'legend', isNew: true),
  SummonResult(crewId: 'crabs', rarity: 'rare', isNew: true),
  SummonResult(crewId: 'volke', rarity: 'mythic', isNew: true),
  SummonResult(crewId: 'pingu', rarity: 'common'),
  SummonResult(crewId: 'starry', rarity: 'common'),
  SummonResult(crewId: 'uni', rarity: 'hero', isNew: true),
];

void main() {
  final enabled = Platform.environment['UI_COMPARE'] == '1';
  setUpAll(loadGoldenFonts);

  testWidgets('소환 연출 프레임 시트 (S24)', skip: !enabled, (tester) async {
    Future<void> shot(String name) async {
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../../../docs/specs/ui-summon-v2/frame_$name.png'),
      );
    }

    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s.copyWith(lastSummon: _ten, wallet: s.wallet.copyWith(gems: 1000)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 420));
    await shot('1_landing');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('2_hint');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('summon.card.2.back')));
    await tester.pump(const Duration(milliseconds: 250));
    await shot('3_flipping');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('summon.revealAll')));
    await tester.pumpAndSettle();
    await shot('4_cutin');
    for (var i = 0; i < 3 && find.byKey(const Key('summon.cutin')).evaluate().isNotEmpty; i++) {
      await tester.tap(find.byKey(const Key('summon.cutin')));
      await tester.pumpAndSettle();
    }
    await shot('5_result');
  });
}
