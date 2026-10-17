import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

class _Painter extends CustomPainter {
  _Painter(this.painter);

  final ScenePainter painter;

  @override
  void paint(ui.Canvas canvas, Size size) => paintTopStd(painter, canvas);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 컷인 띠 안 HD 보스(S5 hd-portrait — S3 확인 요청): 띠 높이 1.6배 칸에서 금관이 잘리지 않는지.
/// 컷인은 해역 보스 첫 등장에만 뜨므로 상태를 직접 세운다(kind = HD 배 보스 중 위로 가장 긴 금관).
void main() {
  testWidgets('HD 보스 컷인 띠', (tester) async {
    final scene = BattleScene(tables, [
      for (var t = 0; t < 4; t++)
        RecordedTick(
          BattleView(tick: t, shipHp: BigNum.from(60), shipHpMax: BigNum.from(60), stage: 50),
          const [],
        ),
    ], loop: false)..update(kFrameMs);
    final cut = tables.fxMap.cutIn;
    scene.moments.cutIn
      ..kind = 'storm_raider'
      ..ageMs = cut.number('inMs') + cut.number('holdMs') / 2
      ..totalMs = cut.number('inMs') + cut.number('holdMs') + cut.number('outMs');
    expect(scene.moments.cutIn.active, isTrue);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: kLogicalWidth,
            height: kLogicalHeight,
            child: CustomPaint(painter: _Painter(ScenePainter(scene))),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_cutin.png'));
  });
}
