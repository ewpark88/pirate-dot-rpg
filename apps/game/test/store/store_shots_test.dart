import 'dart:io';

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/ui/crew/new_mate.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';

import '../ui/ui_harness.dart' show crewTab, loadGoldenFonts, precacheImages, summonTab, voyageTab;
import 'store_shot_kit.dart';

/// 스토어 스크린샷 8장 굽기 (docs/store/listing.ko.md 목록 순서, 2026-10-18 개편 후 화면 — HD 몬스터·대보스·쿵푸 UI·
/// 피버 v2·보스 브레이크·연쇄 번개·새 동료 카드). 골든이 아니다 — 비교하지 않고 PNG를 쓴다. 도구는 store_shot_kit.dart.
///
///     cd apps/game
///     STORE_SHOTS=ko flutter test test/store/store_shots_test.dart   → build/store/screens/ko/01_….png
///     STORE_DEVICE=tablet10 STORE_SHOTS=ko flutter test …                → build/store/screens/tablet10/ko/ (tablet7도 있음)
///     python -I -B docs/store/flatten_png.py                              → Play 규격 24비트 PNG(알파 없음)로
///     STORE_SHOTS=en flutter test test/store/store_shots_test.dart
///
/// 평소(check)에는 건너뛴다. 메모리를 아끼려고 한 번에 한 언어만 굽는다.
/// 전장은 **실제 엔진**을 샘플 상태에서 돌린 기록을 렌더 레인의 BattleScene·ScenePainter로 그린다(HD 종은 그릴 때 기기
/// 해상도로 구워진다 — 앱과 같은 그림). 411×731 논리 × 2.625 = 1080×1920 (Play 휴대전화 9:16). 운영자 패널은 없다.
void main() {
  final lang = Platform.environment['STORE_SHOTS'];
  // 기기: phone(기본) · tablet7 · tablet10 — Play 태블릿 스크린샷은 세로 9:16, 1080~7680px.
  final device = shotDevices[Platform.environment['STORE_DEVICE'] ?? 'phone']!;
  final enabled = lang == 'ko' || lang == 'en';
  final tables = GameTables.load();
  SpriteBank? bank;
  // 탭·창 화면 배경: 후반 샘플(전 선원 신화·큰 배)을 해역마다 옮겨 하늘·바다 색이 장마다 다르게. 필요할 때 만든다(메모리).
  final lateRuns = <int, ShotRun>{};
  ShotMoment late(int stage) => lateRuns
      .putIfAbsent(
        stage,
        () => ShotRun(
          tables,
          shotFixture('all_crews_mythic', skin: 'phantom'),
          ticks: 320,
          commands: {
            0: [OpJumpStage(stage)],
          },
        ),
      )
      .at(300);
  // 운영자 명령은 엔진 기록에만 쓴다 — listing: "샘플 상태로 화면을 맞춘다". 모두 무적.
  // 중반 함대(스테이지 37 샘플)를 산호해 44·무리 40으로: 실제 37 무리(7마리)는 화면 끝에서 다 죽어 장면이 비어 보인다.
  ShotRun swarm(GameState s, {required int ticks, int stage = 44}) => ShotRun(
    tables,
    s,
    ticks: ticks,
    commands: {
      0: [const OpSetInvincible(on: true), OpJumpStage(stage), const OpSetWave(count: 40)],
    },
  );

  Future<void> shot(
    WidgetTester tester,
    String file,
    ShotMoment m, {
    int tab = voyageTab,
    List<Override> extra = const [],
    Future<void> Function()? act,
  }) async {
    bank ??= (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final painter = ScenePainter(m.play(tables))..sprites = bank;
    await pumpShot(tester, m.state, locale: Locale(lang!), tab: tab, painter: painter, device: device, extra: extra);
    if (act != null) await act();
    await precacheImages(tester);
    await saveShot(tester, '../../build/store/screens/${device.dir}$lang/$file.png', device);
  }

  /// 창이 뜨는 애니메이션(미리보기 전장·0.8초 고리 그림은 끝없이 돈다 — pumpAndSettle 대신 시간만 흘린다).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUpAll(() async {
    if (enabled) await loadGoldenFonts();
  });

  group('스토어 스크린샷 ($lang)', skip: !enabled, () {
    testWidgets('01 HD 몬스터 무리 동시 처치', (tester) async {
      final mid = swarm(shotFixture('stage37_midgame', skin: 'coral'), ticks: 2600);
      // 동시 처치 가운데 화면에 적이 가장 많은 순간.
      await shot(tester, '01_multikill', mid.best((e) => e is MultiKill && e.count >= 3, ticks: 3));
    });

    testWidgets('02 피버 v2 — 몰려드는 무리', (tester) async {
      // 피버 게이지 0.95에서 시작 → 피버가 켜지면 무리가 2.5배로 몰려온다. 켜진 뒤 1~4초 중 화면이 가장 찬 순간.
      final fever = swarm(shotFixture('stage37_midgame', fever: 0.95, skin: 'storm'), ticks: 900);
      await shot(tester, '02_fever', fever.crowded((e) => e is FeverStarted, from: 30, to: 120));
    });

    testWidgets('03 대보스 브레이크', (tester) async {
      // 폭풍해 80 대보스(괴물 고래, 88도트). 중반 함대는 보스를 오래 붙잡아 브레이크(기절·피해 증가)가 걸린다 — 걸린 직후.
      final boss = ShotRun(
        tables,
        shotFixture('stage37_midgame', skin: 'gold'),
        ticks: 900,
        commands: {
          0: [const OpJumpStage(80), const OpSetInvincible(on: true)],
          20: [const OpSpawnBoss()],
        },
      );
      await shot(tester, '03_boss_break', boss.after((e) => e is BossBroken, ticks: 8));
    });

    testWidgets('04 연쇄 번개', (tester) async {
      // 연쇄 선원(볼트 번개·범고래·수달 물수제비)만 출전 — 볼트 번개가 3마리 이상 이어진 순간.
      final chain = swarm(
        shotFixture('all_crews_mythic', skin: 'phantom', fleet: ['volt', 'orca', 'otter']),
        ticks: 900,
        stage: 120,
      );
      final volt = chain.best((e) => e is AttackFired && e.crewId == 'volt' && e.targetIds.length >= 3, ticks: 2);
      await shot(tester, '04_chain', volt);
    });

    testWidgets('05 새 동료 카드', (tester) async {
      // 보스 드롭 등으로 새 선원이 합류하면 뜨는 '새 동료!' 카드(역할·싸우는 법·출전시키기·도감 보상).
      await shot(
        tester,
        '05_new_mate',
        late(60),
        act: () async {
          final context = tester.element(find.byKey(const Key('tab.$voyageTab')));
          // 창은 닫을 때까지 열려 있다 — 기다리지 않는다.
          // ignore: unawaited_futures
          showSkinDialog<void>(
            context,
            builder: (_) => const NewMateDialog(crewId: 'volt', rarityId: 'legend'),
          );
          await settle(tester);
        },
      );
    });

    testWidgets('06 선원 상세(공격 미리보기)', (tester) async {
      // 쿵푸 UI 선원 창: 큰 초상·등급·특색·실제 엔진으로 돌리는 공격 미리보기.
      await shot(
        tester,
        '06_crew_detail',
        late(270),
        tab: crewTab,
        act: () async {
          final card = find.byKey(const Key('crew.card.volt'));
          final list = find.descendant(of: find.byKey(const Key('sheet.panel')), matching: find.byType(Scrollable));
          await tester.scrollUntilVisible(card, 200, scrollable: list.first);
          await tester.tap(card);
          await settle(tester);
        },
      );
    });

    testWidgets('07 10연 소환 결과', (tester) async {
      const ten = [
        SummonResult(crewId: 'manta', rarity: 'legend', isNew: true),
        SummonResult(crewId: 'starry', rarity: 'common'),
        SummonResult(crewId: 'uni', rarity: 'hero'),
        SummonResult(crewId: 'pingu', rarity: 'rare'),
        SummonResult(crewId: 'pang', rarity: 'common'),
        SummonResult(crewId: 'crabs', rarity: 'rare'),
        SummonResult(crewId: 'octo', rarity: 'common'),
        SummonResult(crewId: 'lamp', rarity: 'hero'),
        SummonResult(crewId: 'pingu', rarity: 'common'),
        SummonResult(crewId: 'bones', rarity: 'common'),
      ];
      final m = late(120);
      await shot(
        tester,
        '07_summon',
        m.withState(m.state.copyWith(lastSummon: ten)),
        tab: summonTab,
        act: () async {
          await tester.pumpAndSettle();
          final reveal = find.byKey(const Key('summon.revealAll'));
          if (reveal.evaluate().isNotEmpty) {
            await tester.tap(reveal);
            await tester.pumpAndSettle();
          }
          // 전설 이상이면 컷인이 하나씩 뜬다 — 눌러 닫아 결과 격자가 보이게.
          for (var i = 0; i < 10 && find.byKey(const Key('summon.cutin')).evaluate().isNotEmpty; i++) {
            await tester.tap(find.byKey(const Key('summon.cutin')));
            await tester.pumpAndSettle();
          }
        },
      );
    });

    testWidgets('08 환생(보물지도)', (tester) async {
      // 후반 상태라 환생이 열려 있다 — 보물지도 카드의 버튼으로 확인 창(얻을 조각·보너스)을 연다.
      await shot(
        tester,
        '08_rebirth',
        late(75),
        act: () async {
          // 도크·시트 화면(탑다운): 항해 카드는 시트 안 — 도크의 항해 아이콘을 눌러 시트를 연다.
          await tester.tap(find.byKey(const Key('tab.$voyageTab')));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          final open = find.byKey(const Key('rebirth.open'));
          // 항해 탭 목록은 보이는 부분만 만든다 — 카드가 생길 때까지 굴린다(지루함 해소 카드가 위에 더 생김).
          await tester.scrollUntilVisible(open, 200, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await tester.tap(open);
          await tester.pumpAndSettle();
        },
      );
    });
  });
}
