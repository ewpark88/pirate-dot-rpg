import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/summon/summon_result.dart';

import 'ui_harness.dart';

/// [i]번 카드가 뒷면(false)·앞면(true)인지. AnimatedSwitcher가 같은 키로 감싸서 위젯 수는 세지 않는다.
void _expectSide(int i, {required bool face}) {
  expect(find.byKey(Key('summon.card.$i.face')), face ? findsWidgets : findsNothing, reason: 'card $i');
  expect(find.byKey(Key('summon.card.$i.back')), face ? findsNothing : findsWidgets, reason: 'card $i');
}

/// 10연 결과: 일반 8 · 희귀 1 · 영웅 1(확정 카드), 옥토는 새 선원.
const _ten = [
  SummonResult(crewId: 'octo', rarity: 'common', isNew: true),
  SummonResult(crewId: 'starry', rarity: 'common'),
  SummonResult(crewId: 'pang', rarity: 'common'),
  SummonResult(crewId: 'pingu', rarity: 'common'),
  SummonResult(crewId: 'octo', rarity: 'common'),
  SummonResult(crewId: 'crabs', rarity: 'rare'),
  SummonResult(crewId: 'pang', rarity: 'common'),
  SummonResult(crewId: 'pingu', rarity: 'common'),
  SummonResult(crewId: 'starry', rarity: 'common'),
  SummonResult(crewId: 'uni', rarity: 'hero'),
];

GameState _withResult({List<SummonResult> results = _ten, int? tutorialStep}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(lastSummon: results, tutorialStep: tutorialStep);
}

Future<void> _revealAll(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('summon.revealAll')));
  await tester.pumpAndSettle();
}

const _mythicOnly = [SummonResult(crewId: 'manta', rarity: 'mythic')];

/// 화면 전체 흰 번쩍임 (신화 기대감, 반투명 흰 ColoredBox).
Iterable<ColoredBox> _flashes(WidgetTester tester) => tester
    .widgetList<ColoredBox>(find.byType(ColoredBox))
    .where((b) => b.color.r == 1 && b.color.g == 1 && b.color.b == 1 && b.color.a > 0 && b.color.a < 1);

/// 창이 뜨고(0.25초) 카드가 깔린 뒤(1장 0.45초) 기대감 중간(0.6초)까지.
Future<void> _toHintPeak(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 460));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('기준 11: 결과가 오면 카드 10장이 뒷면으로', (tester) async {
    await pumpGame(tester, _withResult());
    await tester.pumpAndSettle();
    expect(find.byType(SummonResultDialog), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      _expectSide(i, face: false);
    }
    expect(find.byKey(const Key('summon.result.ok')), findsNothing); // 다 뒤집어야 닫는다
  });

  testWidgets('카드를 누르면 한 장만 뒤집힌다', (tester) async {
    await pumpGame(tester, _withResult());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('summon.card.0.back')).first);
    await tester.pumpAndSettle();
    _expectSide(0, face: true);
    for (var i = 1; i < 10; i++) {
      _expectSide(i, face: false);
    }
  });

  testWidgets('기준 11: 모두 뒤집기 → 영웅 이상 강조, 새 선원 NEW', (tester) async {
    await pumpGame(tester, _withResult());
    await tester.pumpAndSettle();
    await _revealAll(tester);
    for (var i = 0; i < 10; i++) {
      _expectSide(i, face: true);
    }
    expect(find.byKey(const Key('summon.card.9.highlight')), findsOneWidget); // 영웅
    expect(find.byKey(const Key('summon.card.5.highlight')), findsNothing); // 희귀는 강조 없음
    expect(find.text('NEW'), findsOneWidget);
  });

  testWidgets('등장 연출: 전설·신화만 테두리 빛, 영웅은 없음', (tester) async {
    const results = [
      SummonResult(crewId: 'manta', rarity: 'legend'),
      SummonResult(crewId: 'uni', rarity: 'hero'),
      SummonResult(crewId: 'octo', rarity: 'mythic'),
    ];
    await pumpGame(tester, _withResult(results: results));
    await tester.pumpAndSettle();
    await _revealAll(tester);
    expect(find.byKey(const Key('summon.card.0.glow')), findsOneWidget);
    expect(find.byKey(const Key('summon.card.1.glow')), findsNothing);
    expect(find.byKey(const Key('summon.card.2.glow')), findsOneWidget);
  });

  testWidgets('등장 연출: 신화는 기대감 중 화면이 번쩍이고 끝나면 사라진다', (tester) async {
    await pumpGame(tester, _withResult(results: _mythicOnly));
    await _toHintPeak(tester);
    expect(_flashes(tester), isNotEmpty);
    await tester.pumpAndSettle();
    expect(_flashes(tester), isEmpty);
  });

  testWidgets('등장 연출: 설정 번쩍임을 끄면 번쩍이지 않는다', (tester) async {
    final off = _withResult(results: _mythicOnly);
    await pumpGame(tester, off.copyWith(settings: off.settings.withValue('flash', false)));
    await _toHintPeak(tester);
    expect(_flashes(tester), isEmpty);
  });

  testWidgets('등장 연출: 전설·신화를 뒤집으면 컷인 → 탭하면 격자로', (tester) async {
    await pumpGame(tester, _withResult(results: _mythicOnly));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('summon.revealAll')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summon.cutin')), findsOneWidget);
    await tester.tap(find.byKey(const Key('summon.cutin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summon.cutin')), findsNothing);
    expect(find.byKey(const Key('summon.again')), findsOneWidget);
  });

  testWidgets('결과: 다시 소환 → Ack + 같은 수 Summon (젬이 충분할 때)', (tester) async {
    final s = _withResult();
    final log = await pumpGame(tester, s.copyWith(wallet: s.wallet.copyWith(gems: 1000)));
    await tester.pumpAndSettle();
    await _revealAll(tester);
    await tester.tap(find.byKey(const Key('summon.again')));
    await tester.pumpAndSettle();
    expect(log.sent.map((c) => c.toJson()), [const AckSummonResult().toJson(), const Summon(count: 10).toJson()]);
  });

  testWidgets('기준 11: 확인 → AckSummonResult, 닫힘', (tester) async {
    final log = await pumpGame(tester, _withResult());
    await tester.pumpAndSettle();
    await _revealAll(tester);
    await tester.tap(find.byKey(const Key('summon.result.ok')));
    await tester.pumpAndSettle();
    expect(log.sent, [isA<AckSummonResult>()]);
    expect(find.byType(SummonResultDialog), findsNothing);
  });

  testWidgets('튜토리얼 4단계면 확인 때 TutorialAck(4)도', (tester) async {
    final log = await pumpGame(tester, _withResult(tutorialStep: 4), keepTutorial: true);
    await tester.pumpAndSettle();
    await _revealAll(tester);
    await tester.tap(find.byKey(const Key('summon.result.ok')));
    expect(log.sent.map((c) => c.toJson()), [const AckSummonResult().toJson(), const TutorialAck(4).toJson()]);
  });

  testWidgets('1회 소환은 카드 1장', (tester) async {
    await pumpGame(
      tester,
      _withResult(
        results: const [SummonResult(crewId: 'manta', rarity: 'legend')],
      ),
    );
    await tester.pumpAndSettle();
    _expectSide(0, face: false);
    expect(find.byKey(const Key('summon.card.1.back')), findsNothing);
  });

  testWidgets('결과가 없으면 창이 없다', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    await tester.pumpAndSettle();
    expect(find.byType(SummonResultDialog), findsNothing);
  });
}
