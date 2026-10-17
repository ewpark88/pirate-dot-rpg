import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/meta/daily_providers.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

import 'ui_harness.dart';

/// M3 메타 기준 10·11: 영어 골든 4장. 경제 함수(B1·B3·B7·B8)가 오기 전이라 provider는 가짜 값.
/// 갱신은 사람이 --update-goldens로만.
void main() {
  setUpAll(loadGoldenFonts);

  Future<void> pump(WidgetTester tester, GameState state, {List<Override> extra = const []}) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trialsEnabledProvider.overrideWithValue(false),
          initialGameStateProvider.overrideWithValue(withGuidesSeen(state)),
          battleViewBuilderProvider.overrideWithValue((_) => const ColoredBox(color: Colors.blueGrey)),
          clockProvider.overrideWithValue(FixedClock(state.savedAt)),
          ...extra,
        ],
        child: const PirateDotApp(locale: Locale('en')),
      ),
    );
    await tester.pump();
    // 도크 + 시트: 항해 패널을 연다(환생 카드·순풍 등이 보이게).
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  final base = loadFixture('stage37_midgame');
  final quests = [
    const QuestView(id: 'kill_500', type: 'kill', progress: 500, target: 500, claimed: true),
    const QuestView(id: 'upgrade_30', type: 'upgrade', progress: 30, target: 30, claimed: false),
    const QuestView(id: 'summon_1', type: 'summon', progress: 0, target: 1, claimed: false),
    const QuestView(id: 'ad_1', type: 'ad', progress: 0, target: 1, claimed: false),
  ];
  final daily = [
    dailyQuestsProvider.overrideWithValue((_) => quests),
    attendanceProvider.overrideWithValue(
      (_, _) => AttendanceView(
        day: 4,
        claimedToday: false,
        rewards: GameTables.load().meta.raw.obj('attendance').objs('rewards'), // 사용자 결정 그대로
      ),
    ),
  ];

  testWidgets('골든: en_m3_hud (목표 막대 + 상자 + 순풍 + 퀘스트 아이콘)', (tester) async {
    // 튜토리얼이 끝난 HUD (가이드 카드는 en_tutorial_step2·guide_test 골든이 본다).
    final state = base.copyWith(
      clearTutorial: true,
      battle: base.battle!.copyWith(chest: const ChestView(x: 220, y: 110, ticksLeft: 500)),
    );
    await pump(
      tester,
      state,
      extra: [
        nextGoalProvider.overrideWithValue(
          (_) => const NextGoal(kind: GoalKind.shipTier, id: 'warship', remaining: 43, progress: 0.15),
        ),
        chestRewardProvider.overrideWithValue((_) => BigNum.parse('2.5e5')),
        ...daily,
      ],
    );
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_m3_hud.png'));
  });

  testWidgets('골든: en_daily_sheet', (tester) async {
    await pump(tester, base, extra: daily);
    await tester.tap(find.byKey(const Key('daily.icon')));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_daily_sheet.png'));
  });

  testWidgets('골든: en_tutorial_step2', (tester) async {
    await pump(tester, base.copyWith(tutorialStep: 2));
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_tutorial_step2.png'));
  });

  testWidgets('골든: en_summon_result (10연, 모두 뒤집음)', (tester) async {
    const ten = [
      SummonResult(crewId: 'octo', rarity: 'common', isNew: true),
      SummonResult(crewId: 'starry', rarity: 'common'),
      SummonResult(crewId: 'pang', rarity: 'common'),
      SummonResult(crewId: 'pingu', rarity: 'common'),
      SummonResult(crewId: 'manta', rarity: 'legend'),
      SummonResult(crewId: 'crabs', rarity: 'rare'),
      SummonResult(crewId: 'pang', rarity: 'common'),
      SummonResult(crewId: 'pingu', rarity: 'common'),
      SummonResult(crewId: 'starry', rarity: 'common'),
      SummonResult(crewId: 'uni', rarity: 'hero'),
    ];
    await pump(tester, base.copyWith(lastSummon: ten));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('summon.revealAll')));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_summon_result.png'));
  });

  // 환생 기준 5: 항해 탭 환생 카드(가능) + 확인 창. 샘플(스테이지 37)은 잠김이라 미리보기를 가짜 값으로.
  final rebirth = rebirthPreviewProvider.overrideWithValue(
    (_) => const RebirthPreview(
      locked: false,
      minStage: 40,
      currentPieces: 2,
      gain: 7,
      nextPieceInStages: 3,
      bonusPerPiece: 0.05,
    ),
  );

  testWidgets('골든: en_rebirth_card', (tester) async {
    await pump(tester, base, extra: [rebirth]);
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_rebirth_card.png'));
  });

  testWidgets('골든: en_rebirth_dialog', (tester) async {
    await pump(tester, base, extra: [rebirth]);
    // 실기기 글자 크기에서는 환생 카드가 탭 아래쪽(아직 안 지어짐) — 스크롤해서 찾는다.
    await tester.scrollUntilVisible(
      find.byKey(const Key('rebirth.open')),
      100,
      scrollable: find.descendant(of: find.byType(VoyageTab), matching: find.byType(Scrollable)).first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_rebirth_dialog.png'));
  });
}
