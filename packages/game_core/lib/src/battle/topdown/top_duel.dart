import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 보스전 비켜서기(사용자 피드백 #10 '보스가 오른쪽 아래 대각선에서 잘린다 — 내 배도 움직여서'):
/// 보스는 배 둘레 standoff(100)를 도는데 카메라 반폭은 90이라 옆·대각선에서 화면 밖으로 나간다.
/// 배가 보스 반대쪽으로 standoff × shift만큼 비켜 서서(0.5면 둘의 가운데가 화면 가운데) 둘 다 화면 안에 둔다.
/// 배는 speed(단위/초)까지만 움직인다 — 보스가 돌면 배도 천천히 따라 돌고, 보스전이 끝나면 같은 속도로 가운데(또는 피버 자리)로 돌아온다.
/// 보스와 배 사이 거리(standoff)는 그대로라 사거리·패턴은 바뀌지 않는다. waves.top.bossDuel이 없으면 지금처럼 가만히.
///
/// v2(사용자 '배가 앞만 보고 움직이니 밋밋하다 — 보스와 마주 보며 돌고, 아래에서 위로 올라가 가운데서 전투', S1 2026-10-17):
/// - 결투 중심을 화면 가운데로 올린다: 바다 가운데(배 자리)보다 viewHeight × rise 위(렌더 TopFrame.kShipAt 0.63 − 0.5 = 0.13).
/// - 배와 보스는 그 중심을 사이에 두고 마주 본다(배 = 중심 − 보스 방향 × standoff × shift). 보스가 돌면 배도 반대편 궤도로 돈다.
/// - 배 머리(shipHeading)는 늘 보스를 향해 초당 turnDegPerSec까지 돈다. 보스전이 끝나면 같은 빠르기로 위(0)·제자리로.
/// 전장 모양 하나의 결투 상태: 결투 중(또는 복귀 중)인가 · 지금 머리 방향 · 마지막으로 움직인 Field.tick(한 틱 한 걸음).
class _DuelState {
  bool duelling = false;
  double heading = 0;
  int tick = -1;
}

final _states = Expando<_DuelState>('topDuelState');

_DuelState _of(TopGeometry g) => _states[g] ??= _DuelState();

class TopDuel {
  TopDuel._(this.shift, this.speed, this.rise, this.turn, this.shiftY);

  static final _cache = Expando<({TopDuel? duel})>('topDuel');

  /// waves.top.bossDuel {shift, speed}. 없으면 null. 표마다 한 번 읽는다(전투가 틱마다 부른다).
  static TopDuel? of(WavesTable w) => (_cache[w] ??= (duel: _read(w))).duel;

  static TopDuel? _read(WavesTable w) {
    final top = w.raw.obj('top');
    if (!top.has('bossDuel')) return null;
    final d = top.obj('bossDuel');
    return TopDuel._(
      d.number('shift'),
      d.number('speed'),
      d.numberOr('rise', 0) * top.number('viewHeight'),
      d.numberOr('turnDegPerSec', 0) * radiansPerDegree,
      d.numberOr('shiftY', d.number('shift')),
    );
  }

  final double shift;

  /// 세로 비켜서기 비율(없으면 shift와 같음). 작으면 보스가 위·아래에 있어도 배가 결투 중심(화면 가운데) 근처에 머문다 —
  /// 가로는 카메라 반폭(90)이 좁아 shift만큼 비켜서야 둘 다 화면 안, 세로는 넉넉하다.
  final double shiftY;
  final double speed;

  /// 결투 중심을 바다 가운데보다 얼마나 위로(전장 단위). 0이면 v1(제자리 둘레).
  final double rise;

  /// 머리 회전 상한(라디안/초). 0이면 머리를 돌리지 않는다(v1 — 기울기 0).
  final double turn;

  /// 강화로 전장 모양을 새로 만들 때 비켜서기 상태를 이어 준다(배 자리는 geometry.dart가 옮긴다).
  static void carry(TopGeometry from, TopGeometry to) {
    final s = _of(from);
    _of(to)
      ..duelling = s.duelling
      ..heading = s.heading
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
    if (st.duelling && st.tick == f.tick) return (x: cur.x, y: cur.y, heading: st.heading);
    st.tick = f.tick;
    final duel = f.bossActive && f.fastSail == null ? _aside(f, g) : null;
    final to = duel == null ? (x: free.x, y: free.y) : (x: duel.x, y: duel.y);
    final dx = to.x - cur.x;
    final dy = to.y - cur.y;
    final d = math.sqrt(dx * dx + dy * dy);
    final max = speed * dt;
    // 머리: 결투 중이면 보스 쪽, 아니면 평소(피버 기울기) — 초당 turn까지만 돈다.
    final want = duel?.face ?? free.heading;
    final turning = turn > 0 && want != st.heading;
    // 결투도 복귀도 아니면 자리는 평소(피버 모션) 그대로 — 머리만 초당 turn까지(보스전 뒤 위로 돌아오는 중일 수 있다).
    // 머리 회전만으로 '결투 중'(이동 속도 speed 제한)이 되면 피버 8자가 초당 speed로 묶인다(proto fever_motion 실패, 2026-10-17).
    if (duel == null && !st.duelling) {
      st.heading = turning ? _turnToward(st.heading, want, turn * dt) : free.heading;
      return (x: free.x, y: free.y, heading: st.heading);
    }
    st
      ..duelling = duel != null || d > max
      ..heading = turn > 0 ? _turnToward(st.heading, want, turn * dt) : (duel == null ? free.heading : 0);
    final next = d <= max ? to : (x: cur.x + dx / d * max, y: cur.y + dy / d * max);
    final kept = _keepOff(f, g, next);
    return (x: kept.x, y: kept.y, heading: st.heading);
  }

  /// 배가 움직여도 보스와 standoff보다 가까워지지 않게(보스가 기절·돌진 중이면 엔진이 보스를 원 위로 다시 세우지 않는다 —
  /// 그때 배가 다가가면 보스가 배에 붙는다, S1 2026-10-17 top_engine 실패). 가까우면 보스 → 배 방향으로 standoff까지 물러난다.
  ({double x, double y}) _keepOff(Field f, TopGeometry g, ({double x, double y}) off) {
    var x = g.base.shipX + off.x;
    var y = g.base.shipY + off.y;
    for (final e in f.foes) {
      final r = g.top.standoffOf(e);
      // 돌진(패턴 steering)은 일부러 배에 박히는 공격이라 막지 않는다(피하면 돌진 피해·침몰이 사라진다).
      if (!e.boss || !e.alive || (e.plan?.steering ?? false)) continue;
      final dx = x - e.x;
      final dy = y - e.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d >= r || d == 0) continue;
      x = e.x + dx / d * r;
      y = e.y + dy / d * r;
    }
    return (x: x - g.base.shipX, y: y - g.base.shipY);
  }

  /// [from]에서 [to]로 가장 짧은 쪽으로 최대 [step]만큼 돈다.
  static double _turnToward(double from, double to, double step) {
    var diff = to - from;
    diff = math.atan2(math.sin(diff), math.cos(diff));
    return diff.abs() <= step ? to : from + diff.sign * step;
  }

  /// 결투 중심(바다 가운데에서 rise 위)을 사이에 두고 살아 있는 보스(분열이면 가운데)의 반대쪽으로 standoff × shift,
  /// 그리고 보스를 향하는 머리 방향(0 위·시계).
  ({double x, double y, double face})? _aside(Field f, TopGeometry g) {
    var n = 0;
    var cx = 0.0;
    var cy = 0.0;
    var r = g.top.bossStandoff;
    for (final e in f.foes) {
      if (!e.boss || !e.alive) continue;
      r = math.max(r, g.top.standoffOf(e)); // 큰 보스는 더 멀리 서니 배도 그만큼 비켜 둘 다 화면 안에
      n++;
      cx += e.x;
      cy += e.y;
    }
    if (n == 0) return null;
    final ux = cx / n - g.top.shipX;
    final uy = cy / n - g.top.shipY;
    final len = math.sqrt(ux * ux + uy * uy);
    if (len == 0) return null;
    return (x: -ux / len * r * shift, y: -rise - uy / len * r * shiftY, face: math.atan2(ux, -uy));
  }
}
