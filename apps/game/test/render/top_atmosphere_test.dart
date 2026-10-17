import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_atmosphere.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';

void main() {
  TopAtmosphere atmo() => TopAtmosphere(tables.fxMap.raw.obj('atmosphere'), SpriteDraw());
  const sec = 1000.0;

  test('시간대: 낮 6분 → 노을 1.5분 → 밤 3분 → 새벽 1.5분, 12분 한 바퀴', () {
    final a = atmo();
    String at(double s) {
      a.update(s * sec, 'coral', Offset.zero, 0, powerSave: false);
      return a.phaseId;
    }

    expect(at(10), 'day');
    expect(at(365), 'dusk');
    expect(at(460), 'night');
    expect(at(640), 'dawn');
    expect(at(730), 'day', reason: '한 바퀴');
  });

  test('바뀔 때 20초에 걸쳐 서서히(중간 프레임은 두 단계 사이 색)', () {
    final a = atmo()..update(340 * sec, 'coral', Offset.zero, 0, powerSave: false);
    final start = a.tint.a;
    a.update(350 * sec, 'coral', Offset.zero, 0, powerSave: false);
    final mid = a.tint.a;
    a.update(365 * sec, 'coral', Offset.zero, 0, powerSave: false);
    expect(mid, greaterThan(start));
    expect(mid, lessThan(a.tint.a));
  });

  test('해역: 유령해는 늘 밤, 심연은 늘 어둡게, 화산해는 늘 화산재', () {
    final a = atmo()..update(10 * sec, 'phantom', Offset.zero, 0, powerSave: false);
    expect(a.phaseId, 'night');
    a.update(10 * sec, 'abyss', Offset.zero, 0, powerSave: false);
    expect(a.dim, greaterThan(0.05)); // 심연은 늘 조금 더 어둡게(사용자 '탁하다' 뒤 0.3 → 0.1)
    final v = atmo()..update(10 * sec, 'volcano', Offset.zero, 0, powerSave: false);
    expect(v.ash, isTrue);
  });

  test('풍경: 시작 20초 뒤 배 앞쪽에서 나타나 흐름과 함께 지나감, 절전이면 멈춤', () {
    final a = atmo()..update(0, 'coral', Offset.zero, 0, powerSave: false);
    expect(a.landmarks, isEmpty);
    a.update(21 * sec, 'coral', Offset.zero, 0, powerSave: false);
    expect(a.landmarks, hasLength(1));
    final l = a.landmarks.single;
    expect(l.pos.dy, lessThan(-100), reason: '앞(위)쪽');
    a.update(22 * sec, 'coral', const Offset(0, 30), 0, powerSave: false);
    expect(l.pos.dy, greaterThan(-260 + 20), reason: '흐름(뒤쪽)으로 지나감');
    final before = l.pos;
    a.update(23 * sec, 'coral', const Offset(0, 60), 0, powerSave: true);
    expect(l.pos, before, reason: '절전: 멈춤');
  });

  testWidgets('가독성 규칙: 밤에도 적 그림 색은 낮과 같다(색조는 바다·풍경만)', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 684);
    const dpr = 2.8125;
    final rec = [
      for (var t = 0; t < 20; t++)
        RecordedTick(
          BattleView(
            tick: t,
            shipHp: BigNum.from(1),
            shipHpMax: BigNum.from(1),
            mode: 'top',
            stage: 31,
            enemies: const [EnemyView(id: 1, kind: 'crab', x: 135, y: 150, hpRatio: 1, heading: -1.5707963)],
          ),
          const [],
        ),
    ];
    Future<Uint8List> shot(double offset) async {
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      for (var i = 0; i < 10; i++) {
        scene.update(kFrameMs);
      }
      final r = PictureRecorder();
      final c = Canvas(r)..scale(dpr);
      painter.paintTop(Canvas(PictureRecorder()), frame);
      // 등장 팝인(모션 v1, 0.24초)이 끝난 뒤 — 적이 제 크기로 그려진 장면에서 비교한다.
      for (var i = 0; i < 20; i++) {
        scene.update(kFrameMs);
      }
      painter
        ..top.atmosphere.offsetMs = offset
        ..paintTop(c, frame);
      final img = await r.endRecording().toImage((box.width * dpr).round(), (box.height * dpr).round());
      final enemyAt = frame.shipScreen + const Offset(0, 150 - 240) * frame.dot;
      final x = (enemyAt.dx * dpr).round();
      final y = (enemyAt.dy * dpr).round();
      final data = (await img.toByteData())!;
      return Uint8List.fromList([
        for (var dy = -3; dy <= 3; dy++)
          for (var dx = -3; dx <= 3; dx++) ...data.buffer.asUint8List(((y + dy) * img.width + (x + dx)) * 4, 4),
      ]);
    }

    final day = (await tester.runAsync(() => shot(0)))!;
    final night = (await tester.runAsync(() => shot(460 * sec)))!;
    expect(night, day);
  });
}
