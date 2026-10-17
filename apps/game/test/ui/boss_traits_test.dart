import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/crew/fleet_sheet.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';

import 'ui_harness.dart';

// 보스 특성 UI (#25): 특성 이름·수치 + 카운터 계열 한 줄, 약점 = 표 약점 + 특성 카운터.

void main() {
  final t = GameTables.load();

  testWidgets('한 줄 요약: 회피 25% · 카운터 계열(최대 3개)에 약함 / 특성 없는 보스는 빈 글', (tester) async {
    late AppLocalizations l;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            l = AppLocalizations.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    final evade = t.regions.bosses['storm_pirate']!;
    final line = traitSummary(l, t, evade);
    expect(line, startsWith('회피 25%'));
    expect(line, endsWith('에 약함'));
    expect('·'.allMatches(line.split(' · ').last).length, lessThanOrEqualTo(2));
    final plain = t.regions.bosses.values.firstWhere((b) => b.traits.isEmpty && b.weakFamilies.isEmpty);
    expect(traitSummary(l, t, plain), isEmpty);
    for (final b in t.regions.bosses.values) {
      expect(bossCounters(b).toSet(), {...b.weakFamilies, ...b.counterFamilies});
      for (final tr in b.traits) {
        expect(traitName(l, tr), isNotEmpty, reason: '${b.id} ${tr.type}');
      }
    }
  });

  testWidgets('이름표: 특성 보스(storm_pirate)면 특성 아이콘 + 한 줄', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, const [BossSpawned(1, kind: 'storm_pirate', timeLimitTicks: 600)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('boss.trait.evade')), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('편성 후보: 다음 보스 카운터 계열 선원에 보스 약점 칩', (tester) async {
    final base = loadFixture('stage37_midgame');
    final families = {for (final id in base.crews.keys) t.crews.byId(id).family};
    // 보유 선원 계열과 카운터가 겹치는 보스가 나오는 스테이지를 고른다(테스트가 헛돌지 않게).
    final stage = [
      for (var i = 1; i <= 300; i++) i,
    ].firstWhere((i) => bossCounters(t.regions.bossAt(i)).any(families.contains));
    final s = base.copyWith(progress: base.progress.copyWith(stage: stage));
    final counters = bossCounters(t.regions.bossAt(stage)).toSet();
    await pumpGame(tester, s, openTab: false);
    final ctx = tester.element(find.byType(HomeScreen));
    openFleetPicker(ctx, 0);
    await tester.pumpAndSettle();
    final owned = s.crews.keys.map(t.crews.byId);
    final hit = owned.where((c) => counters.contains(c.family)).map((c) => c.id).toList();
    final miss = owned.where((c) => !counters.contains(c.family)).map((c) => c.id).toList();
    expect(hit, isNotEmpty);
    for (final id in hit) {
      expect(find.byKey(Key('fleet.counter.$id'), skipOffstage: false), findsOneWidget, reason: id);
    }
    for (final id in miss) {
      expect(find.byKey(Key('fleet.counter.$id'), skipOffstage: false), findsNothing, reason: id);
    }
  });

  for (final (name, size, dpr) in [('360', const Size(360, 640), 3.0), ('s24', s24Size, s24Dpr)]) {
    testWidgets('골든: 특성 보스 이름표 ko $name', (tester) async {
      await loadGoldenFonts();
      final feed = StreamController<RecordedTick>.broadcast(sync: true);
      addTearDown(feed.close);
      final s = loadFixture('stage37_midgame');
      await pumpGame(
        tester,
        s,
        openTab: false,
        size: size,
        dpr: dpr,
        locale: const Locale('ko'),
        overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
      );
      feed.add(RecordedTick(s.battle!, const [BossSpawned(1, kind: 'monster_whale', timeLimitTicks: 600)]));
      await tester.pump();
      await precacheImages(tester);
      await tester.pump(const Duration(milliseconds: 700));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_traits_intro_$name.png'));
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
