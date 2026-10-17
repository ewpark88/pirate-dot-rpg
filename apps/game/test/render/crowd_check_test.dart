import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/demo/stress_recording.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/text/outline_digits.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';

/// 가독성 점검 도구(S1 — 골든 아님): 피버 200마리 + 계열 착탄 11종 + 숫자가 한꺼번에 — 배·보스가 묻히는지 눈으로 본다.
/// STRIP_DIR이 있을 때만 0.5초 간격 6장을 쓴다.
void main() {
  final dir = Platform.environment['STRIP_DIR'];
  for (final (count, fever, tag) in const [(200, true, 'crowd'), (40, false, 'normal')]) {
    testWidgets('붐빔 장면 $count마리 피버 $fever', skip: dir == null, (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      final digits = (await tester.runAsync(() => OutlineDigits.load(devicePixelRatio: dpr)))!;
      const box = ui.Size(384, 684);
      final base = stressRecording(count: count);
      const fams = [
        'lob',
        'ring',
        'cluster',
        'direct',
        'pierce',
        'laser',
        'skip',
        'underwater',
        'air',
        'assault',
        'shock',
      ];
      const crews = {
        'lob': 'octo',
        'ring': 'pang',
        'cluster': 'turtle',
        'direct': 'gull',
        'pierce': 'sword',
        'air': 'pelly',
      };
      final rec = [
        for (var i = 0; i < base.length; i++)
          () {
            final f = base[i].frame;
            final frame = BattleView.fromJson({
              ...f.toJson(),
              'feverTicksLeft': fever ? 500 : 0,
              'fleet': [
                for (final id in const ['octo', 'pang', 'sword', 'turtle', 'pelly', 'gull'])
                  {'crewId': id, 'cooldown': 0, 'skillCooldown': 0, 'rarity': 4},
              ],
            });
            final e = f.enemies[i % f.enemies.length];
            final e2 = f.enemies[(i * 7) % f.enemies.length];
            final fam = fams[i % fams.length];
            return RecordedTick(frame, [
              ...base[i].events,
              AttackFired(
                f.tick,
                crewId: crews[fam] ?? 'octo',
                family: fam,
                targetIds: [e.id],
                x: e.x,
                y: e.y,
                kind: 'ball',
                flightTicks: 0,
                splashRadius: 26,
              ),
              Damage(f.tick, targetId: e2.id, amount: BigNum.from(1234 + i * 977), crit: i % 4 == 0, crewId: 'octo'),
            ]);
          }(),
      ];
      final scene = BattleScene(tables, rec)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)
        ..sprites = bank
        ..digits = digits;
      final frame = topFrameFor(box, dpr);
      final warm = ui.Canvas(ui.PictureRecorder());
      for (var shot = 0; shot < 6; shot++) {
        for (var i = 0; i < 30; i++) {
          scene.update(kFrameMs);
          painter.paintTop(warm, frame);
        }
        final pr = ui.PictureRecorder();
        painter.paintTop(ui.Canvas(pr)..scale(dpr), frame);
        final img = await tester.runAsync(
          () => pr.endRecording().toImage((box.width * dpr).round(), (box.height * dpr).round()),
        );
        final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
        File('$dir/$tag$shot.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  }
}
