import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_data/game_data.dart';

/// 보스전 비켜서기(사용자 피드백 #10 '보스가 오른쪽 아래 대각선에서 잘린다 — 내 배도 움직여서'):
/// 보스는 배 둘레 standoff(100)를 도는데 카메라 반폭은 90이라 옆·대각선에서 화면 밖으로 나간다.
/// 배가 보스 반대쪽으로 standoff × shift만큼 비켜 서서(0.5면 둘의 가운데가 화면 가운데) 둘 다 화면 안에 둔다.
/// 배는 speed(단위/초)까지만 움직인다 — 보스가 돌면 배도 천천히 따라 돌고, 보스전이 끝나면 같은 속도로 가운데(또는 피버 자리)로 돌아온다.
/// 보스와 배 사이 거리(standoff)는 그대로라 사거리·패턴은 바뀌지 않는다. waves.top.bossDuel이 없으면 지금처럼 가만히.
/// 전장 모양 하나의 비켜서기 상태: 비켜서는 중(또는 복귀 중)인가 · 마지막으로 움직인 Field.tick(한 틱에 shapeField가 여러 번 불려도 한 걸음만).
class _DuelState {
  bool duelling = false;
  int tick = -1;
}

final _states = Expando<_DuelState>('topDuelState');

_DuelState _of(TopGeometry g) => _states[g] ??= _DuelState();

class TopDuel {
  TopDuel._(this.shift, this.speed);

  static final _cache = Expando<({TopDuel? duel})>('topDuel');

  /// waves.top.bossDuel {shift, speed}. 없으면 null. 표마다 한 번 읽는다(전투가 틱마다 부른다).
  static TopDuel? of(WavesTable w) => (_cache[w] ??= (duel: _read(w))).duel;

  static TopDuel? _read(WavesTable w) {
    final top = w.raw.obj('top');
    if (!top.has('bossDuel')) return null;
    final d = top.obj('bossDuel');
    return TopDuel._(d.number('shift'), d.number('speed'));
  }

  final double shift;
  final double speed;

  /// 강화로 전장 모양을 새로 만들 때 비켜서기 상태를 이어 준다(배 자리는 geometry.dart가 옮긴다).
  static void carry(TopGeometry from, TopGeometry to) {
    final s = _of(from);
    _of(to)
      ..duelling = s.duelling
      ..tick = s.tick;
  }

  /// 이번 틱 배 자리(바다 가운데에서 옮긴 값). [free]는 보스전이 아닐 때의 자리(피버 좌우 이동, 없으면 0).
  /// 보스전이거나 아직 [free]로 돌아가는 중이면 속도 상한으로 다가가고, 그 밖엔 [free] 그대로.
  ({double x, double y, double heading}) step(
    Field f,
    TopGeometry g,
    ({double x, double y, double heading}) free, {
    required double dt,
  }) {
    final st = _of(g);
    final cur = (x: g.top.shipX - g.base.shipX, y: g.top.shipY - g.base.shipY);
    if (st.duelling && st.tick == f.tick) return (x: cur.x, y: cur.y, heading: g.shipHeading);
    st.tick = f.tick;
    final duel = f.bossActive && f.fastSail == null ? _aside(f, g) : null;
    final to = duel ?? (x: free.x, y: free.y);
    final dx = to.x - cur.x;
    final dy = to.y - cur.y;
    final d = math.sqrt(dx * dx + dy * dy);
    final max = speed * dt;
    if (duel == null && !st.duelling) return free;
    st.duelling = duel != null || d > max;
    if (d <= max) return (x: to.x, y: to.y, heading: duel == null ? free.heading : 0);
    return (x: cur.x + dx / d * max, y: cur.y + dy / d * max, heading: 0);
  }

  /// 살아 있는 보스(분열이면 가운데)의 반대쪽으로 standoff × shift.
  ({double x, double y})? _aside(Field f, TopGeometry g) {
    var n = 0;
    var cx = 0.0;
    var cy = 0.0;
    for (final e in f.foes) {
      if (!e.boss || !e.alive) continue;
      n++;
      cx += e.x;
      cy += e.y;
    }
    if (n == 0) return null;
    final ux = cx / n - g.top.shipX;
    final uy = cy / n - g.top.shipY;
    final len = math.sqrt(ux * ux + uy * uy);
    if (len == 0) return null;
    final r = g.top.bossStandoff * shift;
    return (x: -ux / len * r, y: -uy / len * r);
  }
}
