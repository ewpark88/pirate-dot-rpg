import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/perf/idle_watch.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../helpers.dart';
import '../top_recording.dart';
import 'counting_canvas.dart';

/// 방치 절전 (사용자: S24 10분 45℃·OLED 잔상, S1): 입력 없음 60초 → 절전 그리기, 3분 → 어두운 점 화면, 입력 즉시 복귀.
void main() {
  test('입력 없음 60초 → idle, 180초 → dim, 입력하면 바로 active', () {
    var t = 0.0;
    final w = IdleWatch(idleMs: 60000, dimMs: 180000, now: () => t)..input();
    t = 59000;
    w.tick();
    expect(w.level.value, IdleLevel.active);
    t = 61000;
    w.tick();
    expect(w.level.value, IdleLevel.idle);
    t = 181000;
    w.tick();
    expect(w.level.value, IdleLevel.dim);
    w.input();
    expect(w.level.value, IdleLevel.active);
    // 사용자 설정 '절전 끔'(0): 오래 둬도 idle까지만.
    w.dimMs = 0;
    t = 900000;
    w.tick();
    expect(w.level.value, IdleLevel.idle);
    // UI가 원본이 되면 스스로 세지 않는다.
    w.follow(IdleLevel.active);
    t = 2000000;
    w.tick();
    expect(w.level.value, IdleLevel.active);
    w.follow(IdleLevel.dim);
    expect(w.level.value, IdleLevel.dim);
  });

  testWidgets('방치 단계마다 절전·어두운 화면, 그리기 수가 준다', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 832);
    final rec = topRecording(
      tables,
      ticks: 400,
      levels: const {'octo': 66, 'pang': 66, 'moray': 66, 'turtle': 66, 'pelly': 66, 'polly': 66},
    );
    final game = BattleGame(tables: tables, recording: rec, loadSprites: false)
      ..onGameResize(Vector2(box.width, box.height));
    game.painter.sprites = bank;
    final frame = topFrameFor(box, 2.8125);
    int calls() {
      final c = CountingCanvas();
      game.painter.paintTop(c, frame);
      return c.calls;
    }

    // 장면 진행 + 실제 Picture 기록 1프레임 평균(ms, 이 PC 기준 — 폰은 비율만 본다).
    double cpuMs() {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
        game.painter.paintTop(Canvas(ui.PictureRecorder()), frame);
      }
      return sw.elapsedMicroseconds / 60 / 1000;
    }

    for (var i = 0; i < 200; i++) {
      game.update(1 / 60);
    }
    final active = calls();
    final activeMs = cpuMs();
    game.idle.level.value = IdleLevel.idle;
    expect(game.scene.settings.powerSave, isTrue);
    expect(game.scene.settings.shake, isFalse);
    expect(game.settings.powerSave, isFalse, reason: '사용자 설정 값은 그대로');
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
    }
    final idle = calls();
    final idleMs = cpuMs();
    game.idle.level.value = IdleLevel.dim;
    expect(game.painter.dim, 0.15);
    final dim = calls();
    final dimMs = cpuMs();
    game.idle.level.value = IdleLevel.active;
    expect(game.painter.dim, isNull);
    expect(game.scene.settings.powerSave, isFalse);
    // 측정 기록
    // ignore: avoid_print
    print(
      '프레임당 그리기 수·CPU: 평소 $active·${activeMs.toStringAsFixed(2)}ms(60fps) · 방치 $idle·${idleMs.toStringAsFixed(2)}ms(30fps) · 어두운 화면 $dim·${dimMs.toStringAsFixed(2)}ms(12fps)',
    );
    expect(dim, lessThan(active ~/ 10));
  });
}
