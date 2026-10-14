import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/paint/status_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

RecordedTick _at(int t, {bool slowed = false, bool burning = false, bool vulnerable = false, bool stunned = false}) =>
    RecordedTick(
      BattleView(
        tick: t,
        shipHp: BigNum.from(60),
        shipHpMax: BigNum.from(60),
        enemies: [
          EnemyView(
            id: 1,
            kind: 'crab',
            x: 200,
            y: 100,
            hpRatio: 1,
            slowed: slowed,
            burning: burning,
            vulnerable: vulnerable,
            stunned: stunned,
          ),
        ],
      ),
      const [],
    );

BattleScene _scene(List<RecordedTick> ticks, {JuiceSettings settings = const JuiceSettings()}) =>
    BattleScene(tables, ticks, loop: false, settings: settings)..update(kFrameMs);

Future<ui.Image> _image(ScenePainter p) {
  final rec = ui.PictureRecorder();
  p.paint(ui.Canvas(rec));
  return rec.endRecording().toImage(kLogicalWidth.toInt(), kLogicalHeight.toInt());
}

Future<int> _rgb(ui.Image img, int x, int y) async {
  final b = (await img.toByteData())!.buffer.asUint8List();
  final i = (y * img.width + x) * 4;
  return (b[i] << 16) | (b[i + 1] << 8) | b[i + 2];
}

int _blue(int rgb) => rgb & 0xFF;

void main() {
  final st = tables.fxMap.status;

  testWidgets('수용 기준 1: 감속이면 파란 색조, 풀리면 원래 색', (tester) async {
    await tester.runAsync(() async {
      final plain = await _rgb(await _image(ScenePainter(_scene([_at(0), _at(1)]))), 200, 100);
      final slowed = await _rgb(
        await _image(ScenePainter(_scene([_at(0, slowed: true), _at(1, slowed: true)]))),
        200,
        100,
      );
      expect(plain, tables.fxMap.enemyLook['basic']!.color & 0xFFFFFF);
      expect(_blue(slowed), greaterThan(_blue(plain) + 40));
    });
  });

  testWidgets('수용 기준 2: 화상 불꽃은 깜빡이고, 번쩍임 끄기면 계속 켜짐', (tester) async {
    await tester.runAsync(() async {
      Future<List<int>> samples(JuiceSettings settings) async {
        final s = _scene([for (var t = 0; t < 10; t++) _at(t, burning: true)], settings: settings);
        final p = ScenePainter(s);
        final xs = StatusPainter.iconXs(1, 200, st.number('iconGap'));
        final y = StatusPainter.iconTop(100 - 6.0).toInt() + 1;
        final out = <int>[];
        for (var i = 0; i < 6; i++) {
          out.add(await _rgb(await _image(p), xs.first.toInt(), y));
          s.update(st.number('burnBlinkMs'));
        }
        return out;
      }

      expect((await samples(const JuiceSettings())).toSet().length, greaterThan(1), reason: '깜빡인다');
      expect((await samples(const JuiceSettings(flash: false))).toSet().length, 1, reason: '고정');
    });
  });

  testWidgets('수용 기준 3: 취약이면 머리 위 빨간 화살표', (tester) async {
    await tester.runAsync(() async {
      final img = await _image(ScenePainter(_scene([_at(0, vulnerable: true), _at(1, vulnerable: true)])));
      final xs = StatusPainter.iconXs(1, 200, st.number('iconGap'));
      final y = StatusPainter.iconTop(100 - 6.0).toInt();
      final red = int.parse(st.str('vulnerableColor').substring(1), radix: 16);
      var found = false;
      for (var dy = 0; dy < 3 && !found; dy++) {
        for (var dx = -1; dx <= 1 && !found; dx++) {
          found = await _rgb(img, xs.first.toInt() + dx, y + dy) == red;
        }
      }
      expect(found, isTrue);
    });
  });

  test('수용 기준 4: 기절·화상·취약 세 표시는 한 줄로 겹치지 않는다', () {
    final gap = st.number('iconGap');
    final xs = StatusPainter.iconXs(3, 200, gap);
    expect(xs, hasLength(3));
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i] - xs[i - 1], greaterThanOrEqualTo(StatusPainter.iconPx + 1));
    }
    expect((xs.first + xs.last) / 2, closeTo(200, 0.5), reason: '가운데 정렬');
  });
}
