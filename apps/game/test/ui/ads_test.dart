import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// 모든 장치가 준비된 가짜 광고. [result]를 돌려주고 본 장치를 기록한다.
class _FakeAds implements AdsPort {
  _FakeAds([this.result = AdResult.rewarded]);

  final AdResult result;
  final shown = <AdPlacement>[];

  @override
  bool isReady(AdPlacement placement) => true;

  @override
  Future<AdResult> show(AdPlacement placement) async {
    shown.add(placement);
    return result;
  }
}

class _FakeAudio implements AudioPort {
  final volumes = <(double, double)>[];

  @override
  void playBgm(String id) {}

  @override
  void playSfx(String id, {int variant = 0, double pitch = 1}) {}

  @override
  void setVolumes({required double sfx, required double bgm}) => volumes.add((sfx, bgm));

  @override
  void stopBgm() {}
}

GameState _base() => loadFixture('stage37_midgame').copyWith(clearTutorial: true);

GameState _withChest(GameState s) =>
    s.copyWith(battle: s.battle!.copyWith(chest: const ChestView(x: 160, y: 60, ticksLeft: 500)));

Future<CommandLog> _pump(WidgetTester tester, GameState state, AdsPort ads, {int tab = 0}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(state),
        commandSinkProvider.overrideWithValue(log),
        battleViewBuilderProvider.overrideWithValue((_) => const SizedBox()),
        clockProvider.overrideWithValue(FixedClock(state.savedAt)),
        adsPortProvider.overrideWithValue(ads),
      ],
      child: const PirateDotApp(locale: Locale('en')),
    ),
  );
  await tester.pump();
  if (tab != 0) {
    await tester.tap(find.byKey(Key('tab.$tab')));
    await tester.pump();
  }
  return log;
}

Finder _ad() => find.byWidgetPredicate((w) => '${w.key}'.contains("'ad."));

void main() {
  testWidgets('기준 1: 기본(NoAds)이면 광고 버튼 0개', (tester) async {
    final farming = _withChest(_base());
    await pumpGame(tester, farming.copyWith(progress: farming.progress.copyWith(farming: true)));
    expect(_ad(), findsNothing);
    await tester.tap(find.byKey(const Key('tab.$summonTab')));
    await tester.pump();
    expect(_ad(), findsNothing);
  });

  testWidgets('기준 2: 상자 ×5 · 젬 — rewarded면 GrantAdReward(chest, gold)', (tester) async {
    final ads = _FakeAds();
    final log = await _pump(tester, _withChest(_base()), ads);
    expect(find.byKey(const Key('ad.chest.gold')), findsOneWidget);
    expect(find.byKey(const Key('ad.chest.gems')), findsOneWidget);
    expect(find.text('Gems 30'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ad.chest.gold')));
    await tester.pump();
    expect(ads.shown, [AdPlacement.chest]);
    expect(log.sent.map((c) => c.toJson()), [const GrantAdReward(AdPlacement.chest, choice: 'gold').toJson()]);
  });

  testWidgets('기준 2: 광고를 닫으면(dismissed) 명령 없음', (tester) async {
    final log = await _pump(tester, _withChest(_base()), _FakeAds(AdResult.dismissed));
    await tester.tap(find.byKey(const Key('ad.chest.gems')));
    await tester.pump();
    expect(log.sent, isEmpty);
  });

  testWidgets('기준 4: 순풍·함포 지원(파밍 중)·무료 소환 자리', (tester) async {
    final s = _base();
    final log = await _pump(tester, s.copyWith(progress: s.progress.copyWith(farming: true)), _FakeAds());
    expect(find.text('30m ×2'), findsOneWidget);
    expect(find.text('Damage +30% · 30s'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ad.bossSupport')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tab.$summonTab')));
    await tester.pump();
    expect(find.textContaining('Free summon · '), findsOneWidget);
    await tester.tap(find.byKey(const Key('ad.freeSummon')));
    await tester.pump();
    expect(log.sent.map((c) => c.toJson()), [
      const GrantAdReward(AdPlacement.bossSupport).toJson(),
      const GrantAdReward(AdPlacement.freeSummon).toJson(),
    ]);
  });

  testWidgets('기준 5: 튜토리얼 중이면 광고 버튼 숨김', (tester) async {
    await _pump(tester, _withChest(_base()).copyWith(tutorialStep: 2), _FakeAds());
    expect(_ad(), findsNothing);
  });

  testWidgets('기준 3: 오프라인 — 받기 뒤 lastOfflineGold가 있으면 ×2 버튼', (tester) async {
    final state = _base().copyWith(lastOfflineGold: BigNum.parse('4.82e6'));
    final log = CommandLog();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialGameStateProvider.overrideWithValue(state),
          commandSinkProvider.overrideWithValue(log),
          adsPortProvider.overrideWithValue(_FakeAds()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OfflineRewardDialog(preview: OfflinePreview(seconds: 3600, gold: BigNum.one, cards: 0)),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('offline.claim')));
    await tester.pump();
    expect(find.text('×2 · +4.82M'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ad.offline')));
    await tester.pump();
    expect(log.sent.map((c) => c.type), ['claimOffline', 'grantAdReward']);
  });

  testWidgets('광고가 준비 안 됐으면 받기 → 바로 닫힘(기존 흐름)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialGameStateProvider.overrideWithValue(_base())],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const OfflineRewardDialog(
                  preview: OfflinePreview(seconds: 3600, gold: BigNum.one, cards: 0),
                ),
              ),
              child: const SizedBox.square(dimension: 40),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offline.claim')));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineRewardDialog), findsNothing);
  });

  testWidgets('기준 6: 효과음 끄기 → setVolumes(sfx: 0)', (tester) async {
    final audio = _FakeAudio();
    final container = ProviderContainer(
      overrides: [
        initialGameStateProvider.overrideWithValue(_base()),
        audioPortProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(container.dispose);
    container.read(battleGameProvider);
    expect(audio.volumes.last, (1.0, 1.0));
    final s = container.read(gameStateProvider);
    container.read(gameStateProvider.notifier).replace(s.copyWith(settings: s.settings.withValue('sfx', false)));
    expect(audio.volumes.last, (0.0, 1.0));
  });
}
