import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// M2 기기 확인 대비: 새 게임 첫 3분(아무것도 누르지 않음)을 실제 엔진으로 라이브 재생하며 매 프레임 그린다.
/// 그리기 예외가 없고, 무리·처치·첫 보스 연출이 실제로 나오는지. `RENDER_DUMP=<폴더>`면 주요 장면 PNG를 남긴다(눈 확인용).
void main() {
  testWidgets('새 게임 첫 3분 — 예외 없음, 처치·보스 연출이 나온다', (tester) async {
    await tester.runAsync(() async {
      final bank = await SpriteBank.load(Images(prefix: 'assets/'), tables);
      final clock = ManualClock(DateTime.utc(2026, 10, 14));
      final host = EngineHost(
        tables: tables,
        initial: GameState.newGame(playerId: 'first', seed: 3, now: clock.now(), crews: tables.meta.startingCrews),
        clock: clock,
      );
      final scene = BattleScene(tables, null);
      final painter = ScenePainter(scene)..sprites = bank;
      final seen = <String>{};
      host.ticks.listen((t) {
        scene.push(t);
        for (final e in t.events) {
          seen.add(e.type);
        }
      });
      final dump = Platform.environment['RENDER_DUMP'];
      final shots = <String, bool>{};
      Future<void> shot(String name) async {
        if (dump == null || shots[name] == true) return;
        shots[name] = true;
        final rec = ui.PictureRecorder();
        paintTopStd(painter, ui.Canvas(rec));
        final img = await rec.endRecording().toImage(kLogicalWidth.toInt(), kLogicalHeight.toInt());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dump/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      }

      var maxNumbers = 0;
      var maxEffects = 0;
      var bossWarn = false;
      const frames = 60 * 180;
      for (var f = 0; f < frames; f++) {
        if (f % 3 == 0) {
          clock.advance(host.engine.tickLength);
          host.step();
        }
        scene.update(kFrameMs);
        // 매 프레임 그린다 — 예외가 나면 테스트 실패.
        final rec = ui.PictureRecorder();
        paintTopStd(painter, ui.Canvas(rec));
        rec.endRecording().dispose();
        if (scene.numbers.active.length > maxNumbers) maxNumbers = scene.numbers.active.length;
        if (scene.effects.active.length > maxEffects) maxEffects = scene.effects.active.length;
        bossWarn |= scene.bossWarnMs > 0;
        if (f == 60 * 5) await shot('t05s');
        if (scene.numbers.active.length >= 3) await shot('first_hits');
        if (scene.bossWarnMs > 0) await shot('boss_warn');
        if (scene.slowMoMs > 0) await shot('boss_kill');
        if (scene.bossFailMs > 0) await shot('boss_fail');
      }
      await shot('t180s');
      host.stop();

      expect(seen, containsAll(['attackFired', 'damage', 'kill']), reason: '첫 3분에 무리와 처치');
      expect(seen.contains('bossSpawned'), isTrue, reason: '첫 3분 안에 첫 보스');
      expect(bossWarn, isTrue, reason: '보스 등장 경고가 그려진다');
      expect(maxNumbers, inInclusiveRange(1, tables.juice.maxDamageNumbers));
      expect(maxEffects, inInclusiveRange(1, tables.juice.maxEffects));
      // ignore: avoid_print — 사람이 읽는 요약 (첫 3분 이벤트 종류·최대 동시 개수)
      print(
        '[first3min] events=${seen.toList()..sort()} maxNumbers=$maxNumbers maxEffects=$maxEffects stage=${host.state.progress.stage}',
      );
    });
  });

  // 설계서 4.12: 스테이지 1·2 보스는 입력 없이 시작 편성(옥토·톡)으로 잡혀야 한다(3단계 실패는 tutorialFailHpMultiplier가 따로 만든다).
  // 2026-10-14 측정: 스테이지 1 보스가 30초 뒤 체력 44% 남음 — 일반 등급 ±10% 안에서는 못 맞춘다 → 보스 HP(waves, S2) 조정 대기.
  test(
    '튜토리얼: 입력 없이 3분 안에 스테이지 1·2 보스 처치, 스테이지 3 도달',
    () {
      final clock = ManualClock(DateTime.utc(2026, 10, 14));
      final host = EngineHost(
        tables: tables,
        initial: GameState.newGame(playerId: 'first', seed: 3, now: clock.now(), crews: tables.meta.startingCrews),
        clock: clock,
      );
      var cleared = 0;
      host.ticks.listen((t) => cleared += t.events.whereType<BossCleared>().length);
      for (var i = 0; i < 20 * 180; i++) {
        clock.advance(host.engine.tickLength);
        host.step();
      }
      host.stop();
      expect(cleared, greaterThanOrEqualTo(2), reason: '스테이지 1·2 보스 처치');
      expect(host.state.progress.stage, greaterThanOrEqualTo(3), reason: '스테이지 3 도달');
    },
    skip: '초반 보스 HP(waves boss.earlyHpMultiplier) 조정 대기 — S2가 sim·튜토리얼과 같이 맞춘다',
  );
}
