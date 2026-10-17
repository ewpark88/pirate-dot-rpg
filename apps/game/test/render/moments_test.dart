import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

RecordedTick _at(int t, int stage, [List<GameEvent> events = const []]) => RecordedTick(
  BattleView(tick: t, shipHp: BigNum.from(60), shipHpMax: BigNum.from(60), stage: stage),
  events,
);

BattleScene _play(List<RecordedTick> ticks, double untilMs) {
  final s = BattleScene(tables, ticks, loop: false);
  var t = 0.0;
  while (t < untilMs) {
    s.update(kFrameMs);
    t += kFrameMs;
  }
  return s;
}

void main() {
  final cut = tables.fxMap.cutIn;
  final cutMs = cut.number('inMs') + cut.number('holdMs') + cut.number('outMs');
  final regionBoss = tables.regions.regionAt(50).regionBoss;
  final midBoss = tables.regions.regionAt(25).midBoss;

  group('수용 기준 1: 해역 보스 첫 등장 컷인', () {
    List<RecordedTick> twice(String kind, int stage) => [
      _at(0, stage),
      _at(1, stage, [BossSpawned(1, kind: kind, timeLimitTicks: 600)]),
      for (var t = 2; t < 60; t++) _at(t, stage),
      _at(60, stage, [BossSpawned(60, kind: kind, timeLimitTicks: 600)]),
      for (var t = 61; t < 80; t++) _at(t, stage),
    ];

    test('켜졌다가 inMs+holdMs+outMs 뒤 꺼진다', () {
      final s = _play(twice(regionBoss, 50), tickMs * 1.2);
      expect(s.moments.cutIn.active, isTrue);
      expect(s.moments.cutIn.kind, regionBoss);
      expect(_play(twice(regionBoss, 50), tickMs + cutMs + 100).moments.cutIn.active, isFalse);
    });

    test('같은 kind 두 번째는 컷인 없음', () {
      final s = _play(twice(regionBoss, 50), tickMs * 60.5);
      expect(s.moments.cutIn.active, isFalse);
    });

    test('중간 보스는 컷인 없음', () {
      expect(_play(twice(midBoss, 25), tickMs * 1.2).moments.cutIn.active, isFalse);
    });
  });

  test('수용 기준 2: 컷인 중에도 재생 위치는 같다', () {
    final withCut = _play([
      _at(0, 50),
      _at(1, 50, [BossSpawned(1, kind: regionBoss, timeLimitTicks: 600)]),
      for (var t = 2; t < 40; t++) _at(t, 50),
    ], tickMs * 20);
    final without = _play([for (var t = 0; t < 40; t++) _at(t, 50)], tickMs * 20);
    expect(withCut.player.position, without.player.position);
  });

  test('수용 기준 3: stage 29→30 + ShipTierUp → 빛기둥 한 번, 배 sloop', () {
    final ticks = [
      _at(0, 29),
      _at(1, 29),
      _at(2, 30, [const ShipTierUp(2, tierId: 'sloop')]),
      for (var t = 3; t < 60; t++) _at(t, 30),
    ];
    final s = _play(ticks, tickMs * 2.2);
    expect(s.moments.shipTierId, 'sloop');
    expect(s.moments.pillarMs, greaterThan(0));
    expect(s.moments.pillarCount, 1);
    final after = _play(ticks, tickMs * 2 + tables.fxMap.pillar.number('ms') + 100);
    expect(after.moments.pillarMs, lessThanOrEqualTo(0));
  });

  test('수용 기준 4: 첫 프레임 stage 80이면 처음부터 warship, 빛기둥 없음', () {
    final s = _play([for (var t = 0; t < 5; t++) _at(t, 80)], tickMs * 2);
    expect(s.moments.shipTierId, tables.shipTiers.tierAt(80).id);
    expect(s.moments.pillarCount, 0);
  });

  test('수용 기준 5: 해역 50→51 → 해일 sweep 1번, 숫자 없음', () {
    final s = _play([_at(0, 50), _at(1, 50), _at(2, 51), for (var t = 3; t < 10; t++) _at(t, 51)], tickMs * 2.2);
    final sheet = tables.fxMap.regionSweep.str('fx');
    expect(s.effects.active.where((e) => e.sheetId == sheet).length, 1);
    expect(s.numbers.active, isEmpty);
    expect(_play([for (var t = 0; t < 10; t++) _at(t, 50)], tickMs * 3).effects.active, isEmpty);
  });

  test('보스 러시 띠: 시작 BOSS RUSH 1/5 → 다음 번호 짧게 → 마지막 앞 붉은 LAST BOSS!', () {
    final m = BattleScene(tables, null).moments..onRushStarted(5); // 라이브 모드(기록 없음)
    expect((m.bannerText, m.bannerSub), ('BOSS RUSH', '1/5'));
    m.onRushBossDown(0);
    expect((m.bannerText, m.bannerSub, m.bannerHot), ('2/5', 'NEXT!', false));
    m.onRushBossDown(3);
    expect((m.bannerText, m.bannerSub, m.bannerHot), ('LAST BOSS!', '5/5', true));
    expect(m.bannerTotal, greaterThan(2000), reason: '마지막 보스 띠는 길게');
  });

  test('요일 던전 띠: MON 3 + 계열, 그 날 계열 착탄 강조 켜짐 → 끝나면 꺼짐', () {
    final scene = BattleScene(tables, null);
    final m = scene.moments..onDungeonStarted('mon', 3, const ['pierce', 'laser']);
    expect((m.bannerText, m.bannerSub), ('MON 3', 'PIERCE · LASER'));
    expect(scene.topHits.impact.hotFamilies, {'pierce', 'laser'});
    m.onDungeonEnded(cleared: false);
    expect((m.bannerText, m.bannerHot), ('FAILED', true));
    expect(scene.topHits.impact.hotFamilies, isEmpty);
  });

  test('보스전 누계 TOTAL: 연속 타격을 더하고 1.5초 끊기면 새로', () {
    final m = BattleScene(tables, null).moments
      ..bossHit(BigNum.from(100), 0)
      ..bossHit(BigNum.from(50), 1000);
    expect(m.bossTotal.toDouble(), 150);
    m.bossHit(BigNum.from(7), 2600);
    expect(m.bossTotal.toDouble(), 7);
  });
}
