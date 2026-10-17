import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/hud/boss_compare.dart';

import 'ui_harness.dart';

// 보스 vs 나 (사용자 피드백 #5): 경제 bossPreview·fleetPower로 '보스 체력 · 약 n초 / 제한 · 한 방 x%' + 여유/빠듯/어려움.

void main() {
  final t = GameTables.load();

  test('계산: 처치 예상 = 체력 ÷ 초당 공격력, 한 방 = 보스 공격 ÷ 배 최대 체력', () {
    final s = loadFixture('stage37_midgame');
    final farming = s.copyWith(progress: s.progress.copyWith(farming: true));
    final v = bossCompareOf(farming, t)!;
    final p = bossPreview(farming, t);
    expect(v.killSec, (p.maxHp / fleetPower(farming, t).dps).toDouble().ceil());
    expect(v.limitSec, (p.timeLimitSec ?? t.waves.raw.obj('boss').number('forecastSec')).ceil());
    final cap = t.waves.raw.number('shipHitCap');
    final raw = (p.attack / farming.battle!.shipHpMax).toDouble();
    expect(v.hitPct, ((raw < cap ? raw : cap) * 100).ceil(), reason: '한 대 상한(shipHitCap) 넘게 보이지 않는다');
    expect(bossCompareOf(s, t), isNull, reason: '파 진행 중(보스·파밍 아님)엔 없음');
  });

  testWidgets('보스전: 게이지 안 다음 목표 자리에 한 줄 + 판정 색(boss.compare.<단계>)', (tester) async {
    final s = loadFixture('boss_fight');
    await pumpGame(tester, s, openTab: false);
    final v = bossCompareOf(s.copyWith(clearTutorial: true), t)!;
    expect(find.byKey(Key('boss.compare.${v.level}')), findsOneWidget);
    expect(find.textContaining('Down in'), findsOneWidget);
    // 게이지 안(다음 목표 자리) — 높이를 늘리지 않는다.
    final gauge = tester.getRect(find.byKey(const Key('hud.gauge')));
    expect(gauge.contains(tester.getCenter(find.byKey(Key('boss.compare.${v.level}')))), isTrue);
  });

  for (final (name, size, dpr) in [('360', const Size(360, 640), 3.0), ('tablet', const Size(800, 1280), 2.0)]) {
    testWidgets('골든: 보스 vs 나 ko $name', (tester) async {
      await loadGoldenFonts();
      await pumpGame(
        tester,
        loadFixture('boss_fight'),
        openTab: false,
        size: size,
        dpr: dpr,
        locale: const Locale('ko'),
      );
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_compare_$name.png'));
    });
  }
}
