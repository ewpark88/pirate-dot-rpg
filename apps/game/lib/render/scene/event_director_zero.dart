part of 'event_director.dart';

/// 피격 보조 + 보스 행동 예고(event_director_top 300줄 한도로 나눔). 0으로 보이는 피해(1 미만 포함)는 숫자 대신 MISS(보호막이면 파란 BLOCK) — 합치기·연쇄 대상 아님(S1 '0은 MISS로').
extension _Zero on EventDirector {
  bool _missed(Damage e, double x, EnemyView t) =>
      scene.isTop && scene.topHits.crew.missIfZero(e.amount, x, t.y - kNumberLiftPx, scene.clockMs, block: t.shielded);

  /// 일반 피격 작은 넉백(S1 '임팩트') — 엔진 넉백(S5 waves.top.knockback)이 켜져 있으면 엔진 자리로만(두 번 안 밀림).
  void _softKnock(int id, Offset at, Offset ship) {
    if (scene.topHits.lite || scene.tables.waves.raw.obj('top').has('knockback')) return;
    scene.topHits.juice.knock(id, at, ship, scene.clockMs, units: 2);
  }

  /// 보스 행동 v2(BossPatternShown): warn → 예고 그림, act → 동작(돌진 자국·장판 폭발 + 큰 흔들림), cancel → 지움.
  void _bossPattern(BossPatternShown e, BattleView frame) {
    final b = scene.topHits.boss;
    final now = scene.clockMs;
    switch (e.phase) {
      case 'warn':
        final warnMs = e.warnTicks * _player.tickMs / math.max(1, frame.speed);
        final def = scene.tables.regions.bosses[scene.poseOf(e.enemyId)?.kind]?.patterns
            .where((p) => p.type == e.kind)
            .firstOrNull;
        b.warn(
          e.enemyId,
          e.kind,
          e.x,
          e.y,
          e.angle,
          e.count,
          e.radius,
          now,
          warnMs,
          aim: scene.topShip,
          spreadDeg: def?.spreadDeg ?? 50,
          homing: def?.homing ?? false,
        );
      case 'act':
        b.act(e.enemyId, now);
        if (e.kind == 'blast' || e.kind == 'charge') scene.shake.trigger(_juice.shake['ultimate']!);
      case 'cancel':
        b.cancel(e.enemyId);
    }
  }
}
