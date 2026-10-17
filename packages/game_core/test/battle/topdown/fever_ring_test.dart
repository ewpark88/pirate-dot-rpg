import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 피버 무리(meta.fever.swarm ring — S1 실기기 2026-10-18 '피버 무리가 가장자리에 몰려 배로 안 온다'):
/// 화면(카메라) 테두리 바로 밖 사방에서 나와(필드 테두리·접근 원 206이 아니라) 피버 10초 안에 배로 조여 온다.
void main() {
  final t = GameTables.load();
  final top = t.waves.raw.obj('top');
  final start = DateTime.utc(2026, 11, 2, 3);

  test('피버 고리는 카메라 테두리 바로 밖에서 — 접근 원보다 가깝고, 몇 초 안에 거의 다 처리된다', () {
    var s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/stage37_midgame.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    s = s.copyWith(progress: s.progress.copyWith(fever: 0.99));
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s)
      ..enqueue(const OpSetInvincible(on: true))
      ..enqueue(const OpJumpStage(37));
    var fever = false;
    var prev = 0;
    List<EnemyView>? ring;
    double? sx;
    double? sy;
    for (var i = 0; i < 1500 && ring == null; i++) {
      e.tick();
      fever |= e.drainEvents().any((x) => x is FeverStarted);
      final v = e.state.battle!;
      final mobs = v.enemies.where((m) => !m.boss).toList();
      if (fever &&
          v.feverTicksLeft > 0 &&
          mobs.length - prev >= t.meta.raw.obj('fever').obj('swarm').integer('max') ~/ 4) {
        ring = mobs;
        sx = v.shipX ?? top.number('shipX');
        sy = v.shipY ?? top.number('shipY');
      }
      prev = mobs.length;
    }
    expect(ring, isNotNull, reason: '피버 중 고리 파가 나왔다');
    final halfDiag = math.sqrt(math.pow(top.number('viewWidth') / 2, 2) + math.pow(top.number('viewHeight') / 2, 2));
    // 가까이 등장(nearSpawn — 일부는 배 둘레에서 솟아오름, emerging)은 고리가 아니라 뺀다.
    final ds = [
      for (final m in ring!)
        if (!m.emerging) math.sqrt(math.pow(m.x - sx!, 2) + math.pow(m.y - sy!, 2)),
    ]..sort();
    expect(ds[ds.length ~/ 2], lessThan(top.number('approachRadius')), reason: '가운데값이 접근 원(206)보다 안쪽');
    expect(ds.first, greaterThan(top.number('viewWidth') / 2), reason: '화면 밖에서 시작');
    expect(ds.last, lessThan(halfDiag + top.number('approachRadius')), reason: '멀리 끼인 적 없음');
  });
}
