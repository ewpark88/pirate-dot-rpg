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

import 'battle_frame_test.dart' show boxOf, devices;
import 'helpers.dart';

/// 보이는 영역 전체(도트 1 = 1px)를 그린다: 필드 왼쪽 위가 (−left, −top)에 오도록 옮긴다.
class _Painter extends CustomPainter {
  _Painter(this.painter, this.view, {this.scale = 1});

  final ScenePainter painter;
  final Rect view;
  final double scale;

  @override
  void paint(ui.Canvas canvas, Size size) {
    canvas
      ..scale(scale)
      ..translate(-view.left, -view.top);
    painter.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 실기기 캡처(device_voyage.png)와 같은 장면: 산호초 stage 14, 보스전 남은 30초, 선원 3명, 함성 60%.
List<RecordedTick> _recording() => [
  for (var t = 0; t < 8; t++)
    RecordedTick(
      BattleView(
        tick: t,
        shipHp: BigNum.from(60),
        shipHpMax: BigNum.from(60),
        stage: 14,
        wave: 2,
        bossActive: true,
        bossTicksLeft: (30 * 1000 / tickMs).round() - t,
        rage: 0.6,
        captainId: 'octo',
        fleet: const [
          FleetSlot(crewId: 'octo', cooldown: 0.4),
          FleetSlot(crewId: 'bones', cooldown: 0.1, rarity: 1),
          FleetSlot(crewId: 'manta', rarity: 3),
        ],
        enemies: [
          EnemyView(id: 99, kind: 'enemy_ship', x: 270 - t * 0.5, y: 120, hpRatio: 0.7, boss: true),
          for (var i = 0; i < 5; i++)
            EnemyView(
              id: i + 1,
              kind: ['crab', 'piranha', 'jelly'][i % 3],
              x: 150.0 + i * 14 - t,
              y: 112.0 + (i * 7 % 18),
              hpRatio: 1,
              layer: i % 3 == 0 ? 'surface' : 'underwater',
            ),
          const EnemyView(id: 50, kind: 'gull', x: 200, y: 52, hpRatio: 1, layer: 'air'),
        ],
      ),
      const [],
    ),
];

void main() {
  for (final MapEntry(key: name, value: (screen, dpr)) in devices.entries) {
    testWidgets('화면 배치 v2 골든 $name: 전장 상자를 빈 띠 없이 채움 + 선원 줄 6칸 + 궁극기 버튼 + 캔버스 HUD', (tester) async {
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      final box = boxOf(screen);
      final frame = battleFrameFor(box, dpr);
      final scene = BattleScene(tables, _recording(), loop: false)..layout = frame;
      for (var i = 0; i < 30; i++) {
        scene.update(kFrameMs);
      }
      final painter = ScenePainter(scene)..sprites = bank;
      final v = frame.viewDots;

      // 실기기 비교용 물리 픽셀 그림 (`RENDER_DUMP=<폴더>`일 때만): 상자 dp × dpr.
      final dump = Platform.environment['RENDER_DUMP'];
      if (dump != null) {
        await tester.runAsync(() async {
          final rec = ui.PictureRecorder();
          _Painter(painter, v, scale: frame.k.toDouble()).paint(ui.Canvas(rec), Size.zero);
          final img = await rec.endRecording().toImage((v.width * frame.k).ceil(), (v.height * frame.k).ceil());
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$dump/layout_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: v.width.ceilToDouble(),
              height: v.height.ceilToDouble(),
              child: CustomPaint(painter: _Painter(painter, v)),
            ),
          ),
        ),
      );
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/layout_$name.png'));
    });
  }
}
