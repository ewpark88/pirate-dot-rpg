import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/pass/pass_sheet.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';

import 'ui_harness.dart';

// 항해 패스 (S2 iap.json pass · ClaimPassReward): 항해 탭 카드(빨간 점) → 시트(무료/유료 두 줄 · 스킨 미리보기 · 모두 받기).

final _t = GameTables.load();

/// 패스 경험치 [xp], 무료 [free]칸 받음, 패스 권리 [paid].
GameState _state({int xp = 0, int free = 0, bool paid = false}) {
  final s = loadFixture('stage37_midgame');
  final at = s.savedAt.toUtc();
  return s.copyWith(
    pass: PassState(season: _t.iap.pass.season, xp: xp, best: s.progress.bestStage, free: free),
    entitlements: paid ? {'pass': Entitlement(since: at, until: at.add(const Duration(days: 20)))} : null,
  );
}

Future<void> _open(WidgetTester tester) async {
  showPixelSheet<void>(
    tester.element(find.byType(HomeScreen)),
    maxHeight: 0.9,
    builder: (_) => const PassSheet(),
  ).ignore();
  await tester.pumpAndSettle();
}

void main() {
  final per = _t.iap.pass.xpPerLevel;

  testWidgets('3단계 · 무료 1칸 받음 → 무료 2칸 금빛, 유료는 자물쇠 · 모두 받기 → ClaimPassReward(free) ×2', (tester) async {
    final log = await pumpGame(tester, _state(xp: per * 3 + 10, free: 1), openTab: false);
    await _open(tester);
    expect(find.text('Level 3/30'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pass.claimAll')));
    await tester.pump();
    expect(log.sent.map((c) => c.toJson()), [
      const ClaimPassReward(paid: false).toJson(),
      const ClaimPassReward(paid: false).toJson(),
    ]);
    expect(find.byKey(const Key('pass.skinPreview')), findsOneWidget);
  });

  testWidgets('패스가 있으면 남은 일수 · 유료 금빛 칸 누름 → ClaimPassReward(paid)', (tester) async {
    final log = await pumpGame(tester, _state(xp: per * 2, free: 2, paid: true), openTab: false);
    await _open(tester);
    expect(find.byKey(const Key('pass.active')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pass.paid.0')));
    await tester.pump();
    expect(log.sent.map((c) => c.toJson()), [const ClaimPassReward(paid: true).toJson()]);
  });

  testWidgets('항해 탭 카드: 받을 것이 있으면 빨간 점', (tester) async {
    await pumpGame(tester, _state(xp: per), size: const Size(400, 1600));
    await tester.ensureVisible(find.byKey(const Key('pass.card')));
    expect(find.byKey(const Key('pass.dot')), findsOneWidget);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [
      ('360', Size(360, 640), 3.0),
      ('384', s24Size, s24Dpr),
      ('411', Size(411, 891), 2.625),
      ('tablet', Size(800, 1280), 2.0),
    ]) {
      testWidgets('패스 시트 ko $name', (tester) async {
        await pumpGame(
          tester,
          _state(xp: per * 4 + 20, free: 2),
          openTab: false,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
        );
        await _open(tester);
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_pass_$name.png'));
      });
    }
  });
}
