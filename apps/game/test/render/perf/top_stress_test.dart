// 탑다운 부하(S1: 화면 동시 적 수십~100, 렌더는 100~150마리에서 60fps): 150마리가 사방에서 배로 다가오며 매 틱 여러 발 발사.
// 숫자는 출력만, 상한은 느슨하게(회귀 방지): 프레임당 그리기 호출 수.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../helpers.dart';
import 'draw_calls_test.dart' show CountingCanvas;

const _kinds = ['crab', 'piranha', 'jelly', 'gull', 'urchin', 'puffer'];

List<RecordedTick> topStress({int count = 150, int ticks = 200}) {
  final rng = math.Random(7);
  final start = [for (var i = 0; i < count; i++) (rng.nextDouble() * 2 * math.pi, 120 + rng.nextDouble() * 120)];
  final crews = ['octo', 'pang', 'sword', 'turtle', 'puffer', 'gull'];
  return [
    for (var t = 0; t < ticks; t++)
      RecordedTick(
        BattleView(
          tick: t,
          shipHp: BigNum.from(100),
          shipHpMax: BigNum.from(100),
          mode: 'top',
          stage: 31,
          fleet: [for (final c in crews) FleetSlot(crewId: c)],
          enemies: [
            for (var i = 0; i < count; i++)
              () {
                final (a, r0) = start[i];
                final r = math.max<double>(40, r0 - t * 0.6);
                return EnemyView(
                  id: i + 1,
                  kind: _kinds[i % _kinds.length],
                  x: 135 + math.cos(a) * r,
                  y: 240 + math.sin(a) * r,
                  hpRatio: 1,
                  heading: a + math.pi,
                  layer: i % 3 == 1 ? 'underwater' : (i % 6 == 3 ? 'air' : 'surface'),
                );
              }(),
          ],
        ),
        [
          for (var k = 0; k < 6; k++) ...[
            AttackFired(
              t,
              crewId: crews[k],
              family: ['lob', 'direct', 'pierce', 'shock', 'underwater', 'air'][k],
              targetIds: [(t * 7 + k * 13) % count + 1],
              x: 135,
              y: 120,
            ),
            Damage(t, targetId: (t * 7 + k * 13) % count + 1, amount: BigNum.from(123 + t), crewId: crews[k]),
          ],
          if (t % 3 == 0) Kill(t, targetId: (t * 11) % count + 1, gold: BigNum.from(9), x: 160, y: 180),
        ],
      ),
  ];
}

void main() {
  testWidgets('탑다운 부하 150마리: 프레임당 그리기 호출·그리기 시간', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 684);
    final scene = BattleScene(tables, topStress())..layout = battleFrameFor(box, 2.8125);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, 2.8125);
    final rec = Canvas(PictureRecorder());
    for (var i = 0; i < 120; i++) {
      scene.update(kFrameMs);
      painter.paintTop(rec, frame);
    }
    var calls = 0;
    final sw = Stopwatch();
    const frames = 300;
    for (var i = 0; i < frames; i++) {
      scene.update(kFrameMs);
      final c = CountingCanvas();
      painter.paintTop(c, frame);
      calls += c.calls;
      sw.start();
      painter.paintTop(rec, frame);
      sw.stop();
    }
    // 측정값을 남긴다(부하 전후 표).
    // ignore: avoid_print
    print(
      '[top stress 150] 그리기 ${calls / frames}/프레임, 기록 ${(sw.elapsedMicroseconds / frames / 1000).toStringAsFixed(2)}ms/프레임 (디버그 JIT, 상대 비교용)',
    );
    expect(calls / frames, lessThan(900));
  });
}
