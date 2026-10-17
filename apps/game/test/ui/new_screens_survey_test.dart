import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/hud/boss_damage.dart' show bossDamageDelay;

import 'ui_harness.dart';

// 2026-10-17 새 화면 4기기 × ko·en 넘침·잘림 점검 (S1 지시): 가이드 v2 카드(튜토리얼 6·시스템 카드)·출항 버튼·빠른 항해 패널·
// 보스 피해 창(MVP)·선원 상세 레벨업 이유·모두 강화·보스 vs 나·브레이크 쿨다운·피버 칩·첫 무료 10연 잠금.
// 그림은 각 화면 골든이 보고, 여기는 RenderFlex 넘침·예외가 없는지만 본다(하네스가 넘침을 예외로 잡는다).

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

final _t = GameTables.load();

GameState _mid() => loadFixture('stage37_midgame');

/// [ids] 말고는 본 것으로 둔 상태 (시스템 카드 하나만 뜨게).
GameState _only(GameState s, Set<String> ids) => s.copyWith(
  settings: Settings.fromJson({
    ...s.settings.toJson(),
    'battleView': s.settings.battleView,
    'hints': [
      for (final id in guideIds)
        if (!ids.contains(id)) id,
    ],
  }),
);

GameState _bossCooldown() {
  final s = loadFixture('boss_fight');
  return s.copyWith(
    battle: s.battle!.copyWith(
      enemies: [
        const EnemyView(id: 1, kind: 'giant_hermit', x: 135, y: 120, hpRatio: 0.7, boss: true, breakCooldown: 0.5),
      ],
      feverTicksLeft: 120,
    ),
  );
}

GameState _fastSail() {
  final s = withCargoRoom(_mid());
  return s.copyWith(
    progress: s.progress.copyWith(stage: 18, rebirths: 1),
    battle: BattleView.fromJson({
      ...s.battle!.toJson(),
      'fastSail': const FastSailView(from: 10, to: 40, combo: 3, phase: 'rush', speed: 4).toJson(),
    }),
  );
}

void main() {
  for (final (name, size, dpr) in _devices) {
    for (final locale in const [Locale('ko'), Locale('en')]) {
      final tag = '$name ${locale.languageCode}';

      testWidgets('$tag: 튜토리얼 카드 1~6', (tester) async {
        for (final step in [1, 2, 3, 4, 5, 6]) {
          await pumpGame(
            tester,
            _mid().copyWith(tutorialStep: step),
            keepTutorial: true,
            openTab: false,
            size: size,
            dpr: dpr,
            locale: locale,
          );
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(seconds: 1));
          expect(find.byKey(const Key('talk')), findsOneWidget, reason: 'step $step');
          expect(tester.takeException(), isNull, reason: 'step $step');
          await tester.pump(const Duration(seconds: 3));
        }
      });

      testWidgets('$tag: 시스템 카드(출항·보스·화물칸·소환)', (tester) async {
        final mid = _mid();
        final cases = <(String, GameState)>[
          ('guide.sail', mid.copyWith(progress: mid.progress.copyWith(sailHold: true))),
          ('guide.boss', loadFixture('boss_fight')),
          ('guide.cargo', mid.copyWith(wallet: mid.wallet.copyWith(gold: goldCapacity(mid, _t)))),
          ('guide.summon', mid.copyWith(wallet: mid.wallet.copyWith(gems: 100000))),
        ];
        for (final (id, s) in cases) {
          await pumpGame(tester, _only(s, {id}), openTab: false, guides: true, size: size, dpr: dpr, locale: locale);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(seconds: 1));
          expect(find.byKey(const Key('talk')), findsOneWidget, reason: id);
          expect(tester.takeException(), isNull, reason: id);
          await tester.pump(const Duration(seconds: 4));
        }
      });

      testWidgets('$tag: 보스전(보스 vs 나·브레이크 쿨다운·피버 칩·모두 강화 알약)', (tester) async {
        await pumpGame(tester, _bossCooldown(), openTab: false, size: size, dpr: dpr, locale: locale);
        expect(find.byKey(const Key('hud.break.clock')), findsOneWidget);
        expect(find.byKey(const Key('fun.fever.chip')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$tag: 빠른 항해 패널 · 배 탭 모두 강화 · 소환 첫 10연 잠금', (tester) async {
        await pumpGame(tester, _fastSail(), openTab: false, size: size, dpr: dpr, locale: locale);
        expect(find.byKey(const Key('fastSail.banner')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final mid = _mid();
        await pumpGame(
          tester,
          mid.copyWith(wallet: mid.wallet.copyWith(gold: goldCapacity(mid, _t))),
          tab: shipTab,
          size: size,
          dpr: dpr,
          locale: locale,
        );
        expect(find.byKey(const Key('upgradeAll')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final first = mid.copyWith(
          summonsTotal: 0,
          wallet: mid.wallet.copyWith(gems: 1000),
          progress: mid.progress.copyWith(bestStage: _t.waves.tutorialFailStage + 1),
        );
        await pumpGame(tester, first, tab: summonTab, size: size, dpr: dpr, locale: locale);
        expect(find.byKey(const Key('summon.firstTenLock')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$tag: 보스 피해 창(MVP) · 선원 상세 레벨업 이유', (tester) async {
        final feed = StreamController<RecordedTick>.broadcast(sync: true);
        addTearDown(feed.close);
        final s = _mid();
        await pumpGame(
          tester,
          s,
          openTab: false,
          size: size,
          dpr: dpr,
          locale: locale,
          overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
        );
        final ids = [for (final f in s.battle!.fleet) f.crewId];
        feed.add(
          RecordedTick(s.battle!, [
            BossCleared(
              9,
              stage: 37,
              gems: 5,
              crewDamage: {for (final (i, id) in ids.indexed) id: BigNum.from(123456789 * (i + 1))},
              mvp: ids.last,
            ),
          ]),
        );
        await tester.pump(bossDamageDelay);
        await tester.pump(const Duration(milliseconds: 600));
        // 처치 창 전에 보상 터짐(젬) — 탭하면 바로 창(S5 reward-fx-wire).
        await tester.tap(find.byKey(const Key('reward.burst')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(const Key('bossDamage')), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byKey(const Key('bossDamage')))).pop();
        await tester.pumpAndSettle();
        unawaited(showCrewDetail(tester.element(find.byType(HomeScreen)), _t.crews.byId(ids.first)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('crew.detail.why')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
