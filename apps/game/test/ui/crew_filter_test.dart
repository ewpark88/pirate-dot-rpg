import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/crew/crew_filter.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/tabs/crew_tab.dart';

import 'ui_harness.dart';

// 도감 합치기 표시 + 정렬·필터 (사용자 직접 지시 2026-10-16).

final _t = GameTables.load();

/// 샘플 + 팡(Lv8)이 합치기로 레벨 업할 수 있게 경험치를 채운 상태.
GameState _withUp() {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(crews: {...s.crews, 'pang': s.crews['pang']!.copyWith(exp: 9999)});
}

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

void main() {
  group('queryCrews (표·경제 함수 그대로)', () {
    final s = loadFixture('stage37_midgame');

    test('번호순 = 40명 번호 순서 · 보유만 = 4명 · 미보유 = 36명', () {
      expect(queryCrews(s, _t, const CrewQuery()).map((c) => c.num), [for (var i = 1; i <= 40; i++) i]);
      expect(queryCrews(s, _t, const CrewQuery(owned: OwnedFilter.owned)), hasLength(s.crews.length));
      expect(queryCrews(s, _t, const CrewQuery(owned: OwnedFilter.unowned)), hasLength(40 - s.crews.length));
    });

    test('등급순: 가장 높은 등급(전설 만타)이 맨 앞 · 공격력순: 보유 선원이 앞, 초당 피해 큰 순', () {
      expect(queryCrews(s, _t, const CrewQuery(sort: CrewSort.rarity)).first.id, 'manta');
      final byDps = queryCrews(s, _t, const CrewQuery(sort: CrewSort.dps));
      final ownedFirst = byDps.take(s.crews.length).map((c) => c.id).toSet();
      expect(ownedFirst, s.crews.keys.toSet());
      final dps = [
        for (final c in byDps.take(s.crews.length)) fleetDps(s, _t, [c.id]),
      ];
      for (var i = 1; i < dps.length; i++) {
        expect(dps[i - 1] >= dps[i], isTrue);
      }
    });

    test('특성 필터는 개성 아이콘과 같은 기준(crewIdentity)', () {
      final boss = queryCrews(s, _t, const CrewQuery(aim: AimKind.boss));
      expect(boss.every((c) => crewIdentity(_t, c.id)!.aim == AimKind.boss), isTrue);
      expect(boss, isNotEmpty);
      expect(queryCrews(s, _t, const CrewQuery(area: true)), hasLength(17));
      final lob = queryCrews(s, _t, const CrewQuery(family: 'lob'));
      expect(lob.every((c) => c.family == 'lob'), isTrue);
    });
  });

  testWidgets('합치기 가능: 카드에 초록 ↑ · "1 can level up" → 그 선원만, 다시 누르면 모두', (tester) async {
    await pumpGame(tester, _withUp(), tab: crewTab, fullSheet: true);
    expect(find.byKey(const Key('crew.up.pang')), findsOneWidget);
    expect(find.byKey(const Key('crew.up.octo')), findsNothing);
    expect(find.text('1 can level up'), findsOneWidget);
    await tester.tap(find.byKey(const Key('crew.upOnly')));
    await tester.pump();
    expect(find.byType(CrewCard), findsOneWidget);
    expect(find.byKey(const Key('crew.card.pang')), findsOneWidget);
    await tester.tap(find.byKey(const Key('crew.upOnly')));
    await tester.pump();
    expect(find.byType(CrewCard), findsNWidgets(40));
  });

  testWidgets('정렬 칩: 번호 → 등급 → 공격력 · 보유 칩: 전체 → 보유 → 미보유', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab, fullSheet: true);
    await tester.tap(find.byKey(const Key('crew.sort')));
    await tester.pump();
    expect(find.text('Rarity'), findsOneWidget);
    await tester.tap(find.byKey(const Key('crew.owned')));
    await tester.pump();
    expect(find.text('Owned'), findsOneWidget);
    expect(find.byType(CrewCard), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('crew.owned')));
    await tester.pump();
    expect(find.byType(CrewCard), findsNWidgets(36));
  });

  testWidgets('필터 시트: 조준 "보스 우선" → 그 선원만 · 아무도 없으면 안내 · 초기화', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab, fullSheet: true);
    await tester.tap(find.byKey(const Key('crew.filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crew.filter.aim.boss')));
    await tester.pump();
    expect(find.text('Filter 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('crew.filter.reset')));
    await tester.pump();
    expect(find.text('Filter 1'), findsNothing);
    // 미보유 + 보유 선원만 있는 계열(=없음)이 되도록: 보유만 + 조준 '공중 우선'(갈매기, 미보유).
    await tester.tap(find.byKey(const Key('crew.filter.aim.air')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // 시트 닫기
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crew.owned')));
    await tester.pump();
    expect(find.byKey(const Key('crew.filter.empty')), findsOneWidget);
  });

  testWidgets('편성 고르기에도 같은 정렬·필터(보유 칩 없음) · 줄마다 특색 아이콘·초당 공격력', (tester) async {
    final base = loadFixture('stage37_midgame');
    final ids = [for (final f in base.battle!.fleet) f.crewId];
    final gap = base.copyWith(fleet: [...ids.take(ids.length - 1), null], fleetInit: true);
    await pumpGame(tester, gap, openTab: false);
    await tester.tap(find.byKey(Key('fleet.slot.${ids.length - 1}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crew.sort')), findsOneWidget);
    expect(find.byKey(const Key('crew.owned')), findsNothing);
    expect(find.byKey(Key('fleet.dps.${ids.last}')), findsOneWidget);
    expect(find.byKey(Key('crew.identity.${ids.last}')), findsOneWidget);
    // 조준 '공중 우선'(보유 없음) → 안내.
    await tester.tap(find.byKey(const Key('crew.filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crew.filter.aim.air')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fleet.pick.empty')), findsOneWidget);
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in _devices) {
      testWidgets('도감 정렬·필터·합치기 표시 $name', (tester) async {
        await pumpGame(
          tester,
          _withUp(),
          tab: crewTab,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          fullSheet: true,
        );
        await precacheImages(tester);
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_crew_filter_$name.png'));
      });
    }

    testWidgets('편성 고르기 360', (tester) async {
      final base = loadFixture('stage37_midgame');
      final ids = [for (final f in base.battle!.fleet) f.crewId];
      final gap = base.copyWith(fleet: [...ids.take(ids.length - 1), null], fleetInit: true);
      await pumpGame(tester, gap, size: const Size(360, 640), dpr: 3, locale: const Locale('ko'), openTab: false);
      await tester.tap(find.byKey(Key('fleet.slot.${ids.length - 1}')));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_fleet_picker_360.png'));
    });

    testWidgets('필터 시트 360', (tester) async {
      await pumpGame(
        tester,
        _withUp(),
        tab: crewTab,
        size: const Size(360, 640),
        dpr: 3,
        locale: const Locale('ko'),
        fullSheet: true,
      );
      await tester.tap(find.byKey(const Key('crew.filter')));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_crew_filter_sheet_360.png'));
    });
  });
}
