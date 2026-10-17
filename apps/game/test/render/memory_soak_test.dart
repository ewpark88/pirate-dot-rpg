import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 메모리 누수 회귀(S5 실기기 PSS 30분에 635 → 1274MB): 보스전(역동 줌·TOTAL·부서짐)과 무리 전투가 섞인 기록을 되풀이해
/// 30분(18000틱)을 그려도 HD 텍스처·버릴 대기·큰 글자 캐시·이펙트 풀·스프라이트 은행이 앞 구간보다 늘지 않는다.
void main() {
  testWidgets('30분 자동 전투 — 그림 메모리가 늘지 않는다', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = ui.Size(384, 684);
    const dpr = 2.8125;
    final rec = topRecording(tables, ticks: 400, stage: 120, bossAt: 5);
    final scene = BattleScene(tables, rec)..layout = battleFrameFor(box, dpr); // 되풀이(loop)
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    final canvas = ui.Canvas(ui.PictureRecorder());
    Map<String, Object> snap() => {
      ...painter.top.memory(),
      'bank': bank.length,
      'effects': scene.effects.active.length,
      'coins': scene.coins.active.length,
      'numbers': scene.numbers.active.length,
    };
    const tickMs = 50.0;
    const frameMs = 100.0; // 빨리 돌리려고 0.1초 프레임(그리기 경로는 같다)
    var t = 0.0;
    Map<String, Object>? early;
    while (t < 18000 * tickMs) {
      scene.update(frameMs);
      painter.paintTop(canvas, frame);
      t += frameMs;
      if (early == null && t >= 3000 * tickMs) early = snap();
    }
    final late = snap();
    // ignore: avoid_print — 진단 출력(실패 때 원인 보기)
    print('early $early\nlate  $late');
    expect(late['bank'], early!['bank'], reason: '스프라이트 은행 이미지가 늘었다');
    expect(late['hdBytes']! as int, lessThanOrEqualTo(late['hdBudget']! as int));
    expect(late['hdRetired'], 0, reason: '버릴 대기 텍스처가 남는다');
    expect(late['labels']! as int, lessThanOrEqualTo(41));
    expect(late['hdSheets']! as int, lessThanOrEqualTo((early['hdSheets']! as int) + 2));
  });
}
