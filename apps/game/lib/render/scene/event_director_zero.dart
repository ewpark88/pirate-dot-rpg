part of 'event_director.dart';

/// 0으로 보이는 피해(1 미만 포함)는 숫자 대신 MISS(보호막이면 파란 BLOCK) — 합치기·연쇄 대상 아님(S1 '0은 MISS로').
extension _Zero on EventDirector {
  bool _missed(Damage e, double x, EnemyView t) =>
      scene.isTop && scene.topHits.crew.missIfZero(e.amount, x, t.y - kNumberLiftPx, scene.clockMs, block: t.shielded);
}
