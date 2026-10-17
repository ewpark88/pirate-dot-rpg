import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

RecordedTick _at(int t) => RecordedTick(
  BattleView(
    tick: t,
    shipHp: BigNum.from(60),
    shipHpMax: BigNum.from(60),
    fleet: const [
      FleetSlot(crewId: 'octo', rarity: 3),
      FleetSlot(crewId: 'crabs', rarity: 1),
    ],
  ),
  const [],
);

Future<int> _rgb(ui.Image img, int x, int y) async {
  final b = (await img.toByteData())!.buffer.asUint8List();
  final i = (y * img.width + x) * 4;
  return (b[i] << 16) | (b[i + 1] << 8) | b[i + 2];
}

int _hex(String s) => int.parse(s.substring(1), radix: 16);

void main() {
  final border = tables.fxMap.slots.integer('border');
  final f = BattleFrame.standard;
  final x0 = f.slotAt(0).dx.toInt();
  final x1 = f.slotAt(1).dx.toInt();
  final top = f.slotAt(0).dy.toInt();

  testWidgets('render-quality-v2 선원 바: 지금 등급(FleetSlot.rarity) 색 두꺼운 테두리 + 계열 색 표식', (tester) async {
    await tester.runAsync(() async {
      final scene = BattleScene(tables, [_at(0), _at(1)], loop: false)..update(kFrameMs);
      final rec = ui.PictureRecorder();
      paintTopStd(ScenePainter(scene), ui.Canvas(rec));
      final img = await rec.endRecording().toImage(kLogicalWidth.toInt(), kLogicalHeight.toInt());

      final legend = _hex(tables.rarities.byId('legend').color);
      final rare = _hex(tables.rarities.byId('rare').color);
      for (var k = 0; k < border; k++) {
        expect(await _rgb(img, x0 + k, top + 12), legend, reason: 'octo(기본 일반 → 지금 전설) 테두리 $k');
        expect(await _rgb(img, x1 + k, top + 12), rare, reason: 'crabs(희귀) 테두리 $k');
      }
      final lob = _hex(tables.fxMap.familyColors.str('lob'));
      expect(await _rgb(img, x0 + border, top + border), lob, reason: '계열 표식');
      // 빈 칸(3~6번째)은 빈 슬롯 테두리. 궁극기 버튼은 없앴다(피버 첫 일격으로 대체, S4 0a9836e4).
      final empty = f.slotAt(2);
      expect(
        await _rgb(img, empty.dx.toInt(), empty.dy.toInt() + 12),
        _hex(tables.fxMap.backgroundLayout.str('slotLine')),
      );
      expect(
        await _rgb(img, empty.dx.toInt() + 5, empty.dy.toInt() + 12),
        _hex(tables.fxMap.slots.str('empty')),
      );
      final u = f.ultimateDots;
      expect(
        await _rgb(img, u.left.toInt(), u.top.toInt() + 5),
        isNot(_hex(tables.fxMap.hud.str('goldColor'))),
        reason: '궁극기 버튼을 그리지 않는다',
      );
    });
  });
}
