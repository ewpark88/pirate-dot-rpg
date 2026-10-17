import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/home_screen.dart';

import 'ui_harness.dart';

// 디자인 개편 ① 스킨 k1 시안 (S1 2026-10-17, docs/plans/active/design-kungfu-style.md): 대표 화면 3장
// (전투 HUD · 배 탭 · 창 하나) × 4기기 — S1이 사용자 기준(쿵푸할매 서바이버)과 비교해 승인한다.

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('384', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

void main() {
  setUpAll(loadGoldenFonts);
  final t = GameTables.load();

  for (final (name, size, dpr) in _devices) {
    testWidgets('k1 전투 HUD $name', (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false, size: size, dpr: dpr);
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/design_k1_hud_$name.png'));
    });

    testWidgets('k1 배 탭 $name', (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), tab: shipTabIndex, size: size, dpr: dpr);
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/design_k1_ship_$name.png'));
    });

    testWidgets('k1 창(선원 상세) $name', (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false, size: size, dpr: dpr);
      final ctx = tester.element(find.byType(HomeScreen));
      showCrewDetail(ctx, t.crews.byId('octo')).ignore();
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/design_k1_dialog_$name.png'));
    });
  }
}
