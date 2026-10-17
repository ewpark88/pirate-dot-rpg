import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/guide/guide_talk.dart';

import 'ui_harness.dart';

// 가이드 v3 스토리보드 (S1 결정 2026-10-17): 첫 5분 흐름을 s24 프레임으로 — S1 승인 뒤 흐름 연결.
// 프레임은 goldens/storyboard_v3_<n>_<lang>.png, 한 줄 띠는 docs/specs/ui-guide-v3/에 이어 붙인다.

class _Fixed extends GuideLineNotifier {
  _Fixed(this.line);

  final GuideLine line;

  @override
  GuideLine? build() => line;
}

typedef _Frame = ({GameState state, int? tab, GuideLine ko, GuideLine en});

GuideLine _l(String text, {String? spot, bool reaction = false, bool dim = false}) =>
    (text: text, spot: spot, reaction: reaction, dim: dim);

void main() {
  final t = GameTables.load();
  final start = loadFixture('new_player').copyWith(clearTutorial: true);
  final rich = start.copyWith(wallet: start.wallet.copyWith(gold: BigNum.from(5000)));
  final farming = rich.copyWith(
    progress: rich.progress.copyWith(stage: t.waves.tutorialFailStage, farming: true, bossFails: 1),
  );
  final gems = start.copyWith(
    wallet: start.wallet.copyWith(gems: 300),
    progress: start.progress.copyWith(stage: t.waves.tutorialFailStage + 1, bestStage: t.waves.tutorialFailStage + 1),
  );

  final frames = <_Frame>[
    (
      state: start,
      tab: null,
      ko: _l('어서 와요, 선장님! 우리 배는 알아서 싸워요. 잠깐 지켜볼까요?'),
      en: _l("Welcome aboard, Captain! Our ship fights on its own. Let's watch."),
    ),
    (
      state: rich,
      tab: null,
      ko: _l('골드가 모였어요! 대포를 키워 볼까요? 여기를 톡!', spot: 'quick.upgrade', dim: true),
      en: _l('We got gold! Shall we power up the cannon? Tap here!', spot: 'quick.upgrade', dim: true),
    ),
    (
      state: rich,
      tab: null,
      ko: _l('좋아요! 공격력 +20% — 괴물이 금방 녹네요.', reaction: true),
      en: _l('Nice! Attack +20% — they melt faster now.', reaction: true),
    ),
    (
      state: farming,
      tab: null,
      ko: _l('보스가 세네요… 배를 조금 더 키우고 다시 붙어 봐요!', spot: 'quick.upgrade'),
      en: _l("That boss is tough… Let's upgrade a bit and try again!", spot: 'quick.upgrade'),
    ),
    (
      state: farming,
      tab: null,
      ko: _l('이번엔 이길 거예요! 보스 도전을 톡!', spot: 'boss.challenge'),
      en: _l("We'll win this time! Tap Boss Challenge!", spot: 'boss.challenge'),
    ),
    (
      state: gems,
      tab: null,
      ko: _l('해냈어요! 젬이 생겼어요. 동료를 불러 볼까요?', spot: 'tab.summon'),
      en: _l('We did it! We got gems. Shall we call some mates?', spot: 'tab.summon'),
    ),
    (
      state: gems,
      tab: summonTab,
      ko: _l('첫 10연은 공짜예요! 여기를 톡!', spot: 'summon.ten'),
      en: _l('Your first 10-pull is free! Tap here!', spot: 'summon.ten'),
    ),
    (
      state: gems,
      tab: null,
      ko: _l('같은 동료가 둘이네요. 합치면 더 세져요!', spot: 'tab.crew'),
      en: _l('Two of the same mate! Merge them to get stronger.', spot: 'tab.crew'),
    ),
    (
      state: start,
      tab: null,
      ko: _l('이제 배가 알아서 싸워요. 앱을 꺼도 골드가 쌓여요!'),
      en: _l('The ship fights on its own now. Gold piles up even when you close the app!'),
    ),
  ];

  for (final lang in ['ko', 'en']) {
    for (final (i, f) in frames.indexed) {
      testWidgets('스토리보드 $lang ${i + 1}', (tester) async {
        await loadGoldenFonts();
        final line = lang == 'ko' ? f.ko : f.en;
        await pumpGame(
          tester,
          f.state,
          tab: f.tab ?? 0,
          openTab: f.tab != null,
          locale: Locale(lang),
          overrides: [
            guideLineProvider.overrideWith(() => _Fixed(line)),
            guidePointedProvider.overrideWithValue({?line.spot}),
          ],
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const Key('talk')), findsOneWidget);
        if (line.spot != null && !line.reaction) expect(find.byKey(const Key('talk.glow.0')), findsOneWidget);
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/storyboard_v3_${i + 1}_$lang.png'));
      });
    }
  }
}
