import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

class _Painter extends CustomPainter {
  _Painter(this.painter);

  final ScenePainter painter;

  @override
  void paint(ui.Canvas canvas, Size size) => painter.paint(canvas);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _crews = ['octo', 'bones', 'sword', 'pingu', 'manta', 'lamp'];

/// 배 앞 밀집 장면 (platform E8): 적 8마리가 배 앞(x 80~120)에 몰리고, 6명이 매 틱 쏜다(가끔 치명타).
List<RecordedTick> _recording() => [
  for (var t = 0; t < 12; t++)
    RecordedTick(
      BattleView(
        tick: t,
        shipHp: BigNum.from(60),
        shipHpMax: BigNum.from(60),
        stage: 12,
        fleet: [for (final c in _crews) FleetSlot(crewId: c)],
        enemies: [
          for (var i = 0; i < 8; i++)
            EnemyView(
              id: i + 1,
              kind: ['crab', 'piranha', 'puffer', 'urchin'][i % 4],
              x: 84.0 + (i * 7 % 36),
              y: 108.0 + (i * 5 % 18),
              hpRatio: 1,
              layer: i % 4 == 1 || i % 4 == 3 ? 'underwater' : 'surface',
            ),
        ],
      ),
      [
        for (var c = 0; c < _crews.length; c++)
          Damage(
            t,
            targetId: 1 + (t + c * 3) % 8,
            amount: BigNum.from(12 + c * 7),
            crit: (t + c) % 7 == 0,
            crewId: _crews[c],
          ),
      ],
    ),
];

void main() {
  testWidgets('피해 숫자 가독성(E8): 배 앞 밀집에서 숫자를 합치고 위로 비켜 쌓는다', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final scene = BattleScene(tables, _recording(), loop: false);
    for (var i = 0; i < 26; i++) {
      scene.update(kFrameMs);
    }
    final painter = ScenePainter(scene)..sprites = bank;
    final dump = Platform.environment['RENDER_DUMP'];
    if (dump != null) {
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        painter.paint(ui.Canvas(rec));
        final img = await rec.endRecording().toImage(kLogicalWidth.toInt(), kLogicalHeight.toInt());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$dump/numbers_${Platform.environment['RENDER_TAG'] ?? 'now'}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: kLogicalWidth,
            height: kLogicalHeight,
            child: CustomPaint(painter: _Painter(painter)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/battle_numbers.png'));
  });
}
