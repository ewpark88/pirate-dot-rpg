import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/operator_panel.dart';
import 'package:pirate_dot/ui/meta/daily_sheet.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_result.dart';

import 'ui_harness.dart';

/// 한국어 화면 확인 (스펙 ui-voyage-a11y ②): 테스트 글꼴에 한글이 없어 골든 대신 ‘넘침 없음’을 본다.
/// 넘침(overflow)은 위젯 테스트에서 예외로 실패한다. 화면 크기 360×640·400×800 두 가지.
const _sizes = [Size(360, 640), Size(400, 800)];
const _ko = Locale('ko');

/// 앱 밖 단독 위젯(창·패널)을 한국어로 띄운다.
Future<void> _pumpAlone(WidgetTester tester, Widget home, Size size, {GameState? state}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [initialGameStateProvider.overrideWithValue(state ?? loadFixture('stage37_midgame'))],
      child: MaterialApp(
        locale: _ko,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final tables = GameTables.load();

  for (final size in _sizes) {
    final tag = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets('ko $tag: 퀘스트·출석 시트', (tester) async {
      await _pumpAlone(tester, const DailySheet(), size);
      expect(find.text('일일 퀘스트'), findsOneWidget);
    });

    testWidgets('ko $tag: 소환 결과(10연, 모두 뒤집음)', (tester) async {
      final ten = [for (final c in tables.crews.crews.take(10)) SummonResult(crewId: c.id, rarity: c.baseRarity)];
      await _pumpAlone(tester, SummonResultDialog(results: ten), size);
      await tester.tap(find.byKey(const Key('summon.revealAll')));
      await tester.pumpAndSettle();
      expect(find.text('확인'), findsOneWidget);
    });

    testWidgets('ko $tag: 환생 확인 창', (tester) async {
      final s = loadFixture('stage37_midgame');
      await _pumpAlone(tester, RebirthDialog(preview: rebirthPreview(s, tables)), size);
      expect(find.text('보물지도 펼치기'), findsOneWidget);
    });

    testWidgets('ko $tag: 복귀 팝업', (tester) async {
      const preview = OfflinePreview(seconds: 7 * 3600 + 59 * 60, gold: BigNum.one, cards: 3);
      await _pumpAlone(tester, const OfflineRewardDialog(preview: preview), size);
      expect(find.text('받기'), findsOneWidget);
    });

    testWidgets('ko $tag: 운영자 패널', (tester) async {
      await _pumpAlone(tester, const OperatorPanel(), size);
      expect(find.text('운영자 모드'), findsOneWidget);
    });

    testWidgets('ko $tag: 튜토리얼 말풍선(가장 긴 6단계)', (tester) async {
      await pumpGame(
        tester,
        loadFixture('new_player').copyWith(tutorialStep: 6),
        locale: _ko,
        size: size,
        keepTutorial: true,
      );
      expect(find.byKey(const Key('tutorial.skip')), findsOneWidget);
    });

    testWidgets('ko $tag: 항해 탭(해역·오프라인·순풍·환생)', (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), locale: _ko, size: size);
      expect(find.text('해역 보스까지 스테이지 13'), findsOneWidget);
    });
  }
  // 접근성(48dp·라벨) 점검은 S1 지시로 ui-quality-v1(도트 UI) 뒤로 미룬다 — 도트 버튼으로 바꾼 뒤 한 번에 맞춘다.
}
