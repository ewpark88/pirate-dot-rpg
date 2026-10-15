import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
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
    // 샘플은 보유 4명이 모두 출전 중 → 출전 안 한 보유 선원(스타리)을 더한다.
    final base = loadFixture('stage37_midgame');
    final s = base.copyWith(crews: {...base.crews, 'starry': base.crews['octo']!});
    final fleet = await _pump(tester, state: s);
    const free = 'starry';
    await _openDetail(tester, free);
    await tester.tap(find.byKey(const Key('crew.detail.deploy.$free')));
    await tester.pumpAndSettle();
    expect(fleet.calls, ['set ${s.battle!.fleet.length} $free']);
  });

  testWidgets('B: 선원 줄 칸 → 후보 시트(보유 선원) → 고르면 그 칸에', (tester) async {
    final fleet = await _pump(tester, tab: voyageTab);
    await tester.tap(find.byKey(const Key('fleet.slot.1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fleet.picker.1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fleet.pick.manta')));
    await tester.pumpAndSettle();
    expect(fleet.calls, ['set 1 manta']);
  });

  testWidgets('B: 찬 칸은 비우기도 된다', (tester) async {
    final fleet = await _pump(tester, tab: voyageTab);
    await tester.tap(find.byKey(const Key('fleet.slot.0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fleet.clear')));
    await tester.pumpAndSettle();
    expect(fleet.calls, ['set 0 -']);
  });

  testWidgets('B: 선원 탭 자동 편성', (tester) async {
    final fleet = await _pump(tester);
    await tester.tap(find.byKey(const Key('fleet.auto')));
    expect(fleet.calls, ['auto']);
  });
}
