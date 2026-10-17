import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/hd/hd_muzzle.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 쏘기 직전 빛: 예고부터 차오르고 쏘면 터짐 — 쏘는 부위(왼쪽 보기 기준 muzzle — 오른쪽 보면 x 뒤집기)에서.
void main() {
  test('쏜 갈매기만 부리 자리에서 0.25초 번쩍', () {
    final gull = hdEnemies['gull']!;
    expect(gull.muzzle, isNotNull, reason: 'S5 muzzle 자리');
    final m = HdMuzzle()..fired(7, 1000);
    final rec = PictureRecorder();
    final c = Canvas(rec);
    m
      ..collect(7, 'gull', 100, 50, 16, right: false, now: 1100)
      ..collect(8, 'gull', 0, 0, 16, right: false, now: 1100) // 안 쏜 적
      ..collect(7, 'gull', 100, 50, 16, right: false, now: 1300); // 0.25초 지남
    expect(m.pending, 1);
    m.paint(c);
    expect(m.pending, 0);
    rec.endRecording().dispose();
    // 자리 계산은 공개 규칙과 같다: x = 100 + muzzle.dx · 16 / (2·extent)
    final r = 16 / (2 * gull.extent);
    expect(100 + gull.muzzle!.dx * r, lessThan(100), reason: '왼쪽 보기면 부리는 왼쪽');
  });

  test('예고(windup)부터 차오르고, 쏘면 터진 뒤 사라짐; 못 쏘면 0.4초 뒤 사그라듦', () {
    final m = HdMuzzle()
      ..windup(1, 0, 400, boss: false)
      ..windup(2, 0, 400, boss: true)
      ..collect(1, 'gull', 0, 0, 16, right: false, now: 200)
      ..collect(2, 'kraken', 0, 0, 56, right: false, now: 200);
    expect(m.pending, 2);
    m
      ..paint(Canvas(PictureRecorder()))
      ..fired(1, 400)
      ..collect(1, 'gull', 0, 0, 16, right: false, now: 500)
      ..collect(2, 'kraken', 0, 0, 56, right: false, now: 750); // 보스는 아직 못 쏨 — 늦은 사그라듦 안
    expect(m.pending, 2);
    m
      ..paint(Canvas(PictureRecorder()))
      ..collect(1, 'gull', 0, 0, 16, right: false, now: 700) // 터진 지 0.3초 — 끝
      ..collect(2, 'kraken', 0, 0, 56, right: false, now: 790);
    expect(m.pending, 1);
  });

  test('EnemyWindup이 장면까지 이어진다: 예고 틱에 그 적 빛이 켜짐(렌더 이벤트 경로)', () {
    final base = topRecording(tables, ticks: 140);
    final at = base.indexWhere((t) => t.frame.enemies.isNotEmpty, 60);
    final id = base[at].frame.enemies.first.id;
    final rec = [
      for (final (i, t) in base.indexed)
        i == at ? RecordedTick(t.frame, [...t.events, EnemyWindup(i, enemyId: id, atTicks: 8, kind: 'ranged')]) : t,
    ];
    final scene = BattleScene(tables, rec, loop: false);
    while (scene.player.position < at + 1) {
      scene.update(16);
    }
    expect(scene.topHits.muzzle.active, 1);
  });
}
