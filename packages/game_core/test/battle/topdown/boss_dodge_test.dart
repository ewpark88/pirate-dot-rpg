import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'still_ship.dart';

/// 보스 공격 진짜 회피(docs/plans/active/platform-boss-dodge.md — waves.top.bossDodge, 기본 꺼짐).
void main() {
  final start = DateTime.utc(2026, 11, 2, 3);

  GameTables tables({bool dodge = false, bool homing = false}) {
    final raw = noDodgeRaw();
    final w = jsonDecode(raw['waves']!) as Map<String, dynamic>;
    final top = w['top'] as Map<String, dynamic>;
    if (dodge) {
      top['bossDodge'] = {'shellRadius': 6, 'chargeOvershoot': 40};
      (top['bossDuel'] as Map<String, dynamic>)['dodge'] = {'dist': 60, 'speed': 400, 'maxX': 70};
    }
    raw['waves'] = jsonEncode(w);
    if (homing) {
      final r = jsonDecode(raw['regions']!) as Map<String, dynamic>;
      for (final b in (r['bosses'] as List).cast<Map<String, dynamic>>()) {
        for (final p in (b['patterns'] as List? ?? const []).cast<Map<String, dynamic>>()) {
          p['homing'] = true;
        }
      }
      raw['regions'] = jsonEncode(r);
    }
    return GameTables.load(raw);
  }

  /// 새 게임 함대가 [boss]와 [sec]초 싸운 이벤트(배 무적 — 맞음/빗나감만 센다).
  ({int missed, int fired, Map<String, int> kinds}) fight(GameTables t, String boss, double sec) {
    // 약한 새 게임 함대 — 중반 함대는 기절·비틀로 예고를 다 취소시켜 패턴이 나가지 않는다.
    final s = GameState.newGame(playerId: 'd', seed: 1, now: start).copyWith(clearTutorial: true);
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s)
      ..enqueue(const OpSetInvincible(on: true))
      ..enqueue(OpSpawnBoss(bossId: boss));
    var missed = 0;
    var acts = 0;
    final kinds = <String, int>{};
    for (var i = 0; i < (sec * 1000 / t.waves.tickMs).round(); i++) {
      e.tick();
      for (final ev in e.drainEvents()) {
        if (ev is BossAttackMissed) {
          missed++;
          kinds[ev.kind] = (kinds[ev.kind] ?? 0) + 1;
        }
        if (ev is BossPatternShown && ev.phase == 'act') acts++;
      }
    }
    return (missed: missed, fired: acts, kinds: kinds);
  }

  test('표 키가 없으면 지금 그대로 — 빗나감 0(늘 맞는다)', () {
    final r = fight(tables(), 'enemy_ship', 30);
    expect(r.fired, greaterThan(2));
    expect(r.missed, 0);
  });

  test('bossDodge + 예고 중 옆으로 비키기: 탄·폭발·돌진이 조준 자리로 가서 빗나가는 일이 생긴다', () {
    final t = tables(dodge: true);
    final volleyBlast = fight(t, 'enemy_ship', 30);
    expect(volleyBlast.fired, greaterThan(2));
    expect(volleyBlast.missed, greaterThan(0), reason: '${volleyBlast.kinds}');
    final charge = fight(t, 'giant_hermit', 40);
    expect(charge.kinds.keys, contains('charge'), reason: '${charge.kinds}');
  });

  test('homing 패턴은 회피 규칙에서도 늘 맞는다 · 이벤트 JSON 왕복', () {
    final r = fight(tables(dodge: true, homing: true), 'enemy_ship', 30);
    expect(r.fired, greaterThan(2));
    expect(r.missed, 0);
    const ev = BossAttackMissed(3, enemyId: 9, kind: 'blast', x: 1.5, y: -2);
    expect(GameEvent.fromJson(ev.toJson()).toJson(), ev.toJson());
  });
}
