import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'still_ship.dart';

/// 피버 무리(meta.fever.swarm ring — S1 실기기 2026-10-18 '피버 무리가 가장자리에 몰려 배로 안 온다'):
/// 화면(카메라) 테두리 바로 밖 사방에서 나와(필드 테두리·접근 원 206이 아니라) 피버 10초 안에 배로 조여 온다.
void main() {
  final t = GameTables.load(stillShipRaw()); // 고리 자리(기하)만 — 순항은 피버 첫 틱 고리(S2 밀도 브랜치 babca986)가 들어온 뒤 함께
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

  test('spawnFromView(waves.top, 기본 꺼짐): 켜면 평소 무리도 카메라 테두리 바로 밖에서 출발 — 접근 원(206)보다 가깝게', () {
    double medianStart({required bool fromView}) {
      final raw = Map<String, String>.of(rawTables);
      final w = jsonDecode(raw['waves']!) as Map<String, dynamic>;
      (w['top'] as Map<String, dynamic>)['spawnFromView'] = fromView;
      raw['waves'] = jsonEncode(w);
      final tt = GameTables.load(raw);
      final e =
          CoreEngine(
              tables: tt,
              clock: ManualClock(start),
              initial: GameState.newGame(playerId: 'v', seed: 3, now: start),
            )
            ..enqueue(const OpSetWave(count: 40))
            ..tick();
      final v = e.state.battle!;
      final ds = [
        for (final m in v.enemies)
          if (!m.emerging) math.sqrt(math.pow(m.x - top.number('shipX'), 2) + math.pow(m.y - top.number('shipY'), 2)),
      ]..sort();
      return ds[ds.length ~/ 2];
    }

    expect(medianStart(fromView: false), greaterThanOrEqualTo(top.number('approachRadius')));
    expect(medianStart(fromView: true), lessThan(top.number('approachRadius')));
    expect(inCamera(t, top.number('shipX'), top.number('shipY')), isTrue);
    expect(inCamera(t, top.number('shipX') + top.number('viewWidth'), top.number('shipY')), isFalse);
  });
}
