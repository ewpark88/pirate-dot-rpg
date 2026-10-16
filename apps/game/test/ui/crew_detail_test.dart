import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';

import 'ui_harness.dart';

/// 사용자 요청 A(선원 상세)·B(수동 편성). 편성 명령은 계약 전이라 가짜 포트로 기록한다.
class _FakeFleet implements FleetCommands {
  final calls = <String>[];

  @override
  void setSlot(int slot, String? crewId) => calls.add('set $slot ${crewId ?? '-'}');

  @override
  void auto() => calls.add('auto');
}

Future<_FakeFleet> _pump(WidgetTester tester, {GameState? state, int tab = crewTab}) async {
  final fleet = _FakeFleet();
  await pumpGame(
    tester,
    state ?? loadFixture('stage37_midgame'),
    tab: tab,
    overrides: [fleetCommandsProvider.overrideWithValue(fleet)],
  );
  return fleet;
}

Future<void> _openDetail(WidgetTester tester, String id) async {
  await tester.ensureVisible(find.byKey(Key('crew.card.$id')));
  await tester.pump();
  await tester.tap(find.byKey(Key('crew.card.$id')));
  await tester.pumpAndSettle();
}

/// 편성: 샘플 전장 선원 중 마지막 칸을 비운 상태 (4칸 중 3칸 출전 → 3번 칸이 열린 빈 칸).
GameState _withGap() {
  final base = loadFixture('stage37_midgame');
  final ids = [for (final f in base.battle!.fleet) f.crewId];
  return base.copyWith(fleet: [...ids.take(ids.length - 1), null], fleetInit: true);
}

/// [_withGap]에서 빠진(쉬는) 선원.
String _gapBenched() => loadFixture('stage37_midgame').battle!.fleet.last.crewId;

void main() {
  testWidgets('A: 보유 선원 카드 → 상세(이름·레벨·파워·계열·스킬, 출전 중이면 내리기)', (tester) async {
    final fleet = await _pump(tester);
    await _openDetail(tester, 'octo');
    expect(find.byKey(const Key('crew.detail.octo')), findsOneWidget);
    Finder inDetail(String text) =>
        find.descendant(of: find.byKey(const Key('crew.detail.octo')), matching: find.text(text));
    expect(inDetail('Octo the Bomber'), findsOneWidget);
    expect(find.byKey(const Key('crew.detail.power')), findsOneWidget);
    expect(inDetail('Lob'), findsOneWidget); // 계열
    expect(inDetail('Cannon Rain'), findsOneWidget); // 계열 스킬
    expect(inDetail('Unlocks when promoted to Legend'), findsOneWidget); // 일반 → 전설 능력 미리보기
    // 옥토는 샘플에서 출전 중 → 내리기
    final slot = loadFixture('stage37_midgame').battle!.fleet.indexWhere((f) => f.crewId == 'octo');
    await tester.tap(find.byKey(const Key('crew.detail.undeploy.octo')));
    expect(fleet.calls, ['set $slot -']);
  });

  testWidgets('A: 미보유 선원 → 실루엣 + 얻는 방법, 출전 버튼 없음', (tester) async {
    await _pump(tester);
    await _openDetail(tester, 'starry');
    expect(find.byKey(const Key('crew.detail.howTo')), findsOneWidget);
    expect(find.byKey(const Key('crew.detail.deploy.starry')), findsNothing);
  });

  testWidgets('A: 전설 선원은 전설 능력을 강조해 보인다', (tester) async {
    await _pump(tester);
    await _openDetail(tester, 'manta'); // 샘플 Lv46 = 전설
    expect(find.text('Unlocks when promoted to Legend'), findsNothing);
    expect(find.textContaining('slowing zone'), findsOneWidget);
  });

  testWidgets('B: 빈 칸이 있으면 출전은 그 칸으로', (tester) async {
    // 편성: 샘플 전장 선원 중 마지막 칸을 비운다. 출전 안 한 보유 선원(스타리)을 더한다.
    final base = loadFixture('stage37_midgame');
    final ids = [for (final f in base.battle!.fleet) f.crewId];
    final s = base.copyWith(
      crews: {...base.crews, 'starry': base.crews['octo']!},
      fleet: [...ids.take(ids.length - 1), null],
      fleetInit: true,
    );
    expect(fleetSlots(s, GameTables.load()), ids.length, reason: '샘플 배 등급 칸 수 = 전장 선원 수');
    final fleet = await _pump(tester, state: s);
    const free = 'starry';
    await _openDetail(tester, free);
    await tester.tap(find.byKey(const Key('crew.detail.deploy.$free')));
    await tester.pumpAndSettle();
    expect(fleet.calls, ['set ${ids.length - 1} $free']);
  });

  testWidgets('B: 열린 빈 칸 → 후보 시트(보유 선원) → 고르면 빈 자리에', (tester) async {
    final fleet = await _pump(tester, state: _withGap(), tab: voyageTab);
    await tester.tap(find.byKey(const Key('fleet.slot.3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fleet.picker.3')), findsOneWidget);
    // 쉬는 선원(빈 칸에서 뺀 선원)이 맨 위.
    final benched = _gapBenched();
    await tester.tap(find.byKey(Key('fleet.pick.$benched')));
    await tester.pumpAndSettle();
    expect(fleet.calls, ['set 3 $benched']);
  });

  testWidgets('B: 출전 중 칸 → 그 선원 상세', (tester) async {
    await _pump(tester, tab: voyageTab);
    await tester.tap(find.byKey(const Key('fleet.crew.0')));
    await tester.pumpAndSettle();
    expect(find.byType(CrewDetailDialog), findsOneWidget);
  });

  testWidgets('B: 잠긴 칸 아래 작은 ‘스테이지 N’', (tester) async {
    await _pump(tester, tab: voyageTab);
    expect(find.byKey(const Key('fleet.locked.label.4')), findsOneWidget);
  });

  testWidgets('B: 선원 탭 자동 편성', (tester) async {
    final fleet = await _pump(tester);
    await tester.tap(find.byKey(const Key('fleet.auto')));
    expect(fleet.calls, ['auto']);
  });

  testWidgets('B: 기본 포트는 계약 명령을 보낸다 (AutoFleet · SetFleetSlot)', (tester) async {
    final log = await pumpGame(tester, _withGap(), tab: crewTab);
    await tester.tap(find.byKey(const Key('fleet.auto')));
    await tester.tap(find.byKey(const Key('tab.$voyageTab')));
    // 시트가 올라오는 시간 (첫 프레임에 애니메이션이 시작된다).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('fleet.slot.3')));
    await tester.pumpAndSettle();
    final benched = _gapBenched();
    await tester.tap(find.byKey(Key('fleet.pick.$benched')));
    await tester.pumpAndSettle();
    expect(log.sent.map((c) => c.toJson()), [const AutoFleet().toJson(), SetFleetSlot(3, benched).toJson()]);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);

    for (final (id, lang) in [('octo', 'ko'), ('manta', 'en')]) {
      testWidgets('선원 상세 $id $lang', (tester) async {
        await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab, locale: Locale(lang));
        await precacheImages(tester);
        await _openDetail(tester, id);
        await precacheImages(tester);
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/${lang}_crew_detail_$id.png'));
      });
    }
  });
}
