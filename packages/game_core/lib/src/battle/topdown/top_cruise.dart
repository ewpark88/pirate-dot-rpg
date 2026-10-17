import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 배 순항(사용자 '내 배가 좀 더 역동적으로 움직이면 좋겠어, 느리게 움직여서 재미가 없네', S1 2026-10-17 — waves.top.cruise):
/// 보스전이 아닐 때 배가 바다 위를 돌아다닌다. 시간 함수가 아니라 속도·가속을 가진 조향이라 출발이 빠르고 도착 때 감속한다.
/// - 순항: 집 자리(바다 가운데에서 homeUp 위) 둘레 8자(wanderX·wanderY, wanderSec)를 따라간다.
/// - 돌진: dashEverySec(+ 0~dashJitterSec)마다 카메라 안 잡몹이 가장 빽빽한 곳(clusterRadius 안 clusterMin 마리 이상)을
///   overshoot만큼 지나치는 자리로 speed × dashSpeedMul로 치고 들어갔다(최대 dashMaxSec) 다시 순항 — 무리를 가르며 지나가는 맛.
/// - 진행 방향은 초당 turnDegPerSec까지만 꺾인다 → 빠를수록 큰 호(급회전·제자리 뱅글 없음 — 예전 '360도 돌며 촐싹' 금지).
/// - 머리(heading)는 바다 흐름(forwardFlow — 배는 늘 앞으로)을 더한 진행 방향, ±maxTiltDeg까지.
/// - 피버: 속도 × feverSpeedMul, 돌진 간격 × feverDashMul.
/// - feverOnly(사용자 결정 2026-10-17): 피버 중에만 순항, 끝나면 감속하며 제자리(settleDist 안에서 정확히 0)로 — 평소 화면은 순항 전과 같다.
/// - 자리는 rect(x 좌우, up 위, down 아래 — 바다 가운데 기준) 밖으로 나가지 않는다(화면·안전 영역).
/// 표에 cruise가 없으면 null — 배는 예전처럼 제자리(피버 땐 meta.fever.weave).
class TopCruise {
  TopCruise._(this.c)
    : speed = c.number('speed'),
      turn = c.number('turnDegPerSec') * radiansPerDegree,
      headingTurn = c.number('headingTurnDegPerSec') * radiansPerDegree,
      maxTilt = c.number('maxTiltDeg') * radiansPerDegree;

  final JsonReader c;
  final double speed;
  final double turn;
  final double headingTurn;
  final double maxTilt;

  static final _cache = Expando<({TopCruise? cruise})>('topCruise');

  static TopCruise? of(WavesTable w) => (_cache[w] ??= (cruise: _read(w))).cruise;

  static TopCruise? _read(WavesTable w) {
    final top = w.raw.obj('top');
    return top.has('cruise') ? TopCruise._(top.obj('cruise')) : null;
  }

  /// 강화로 전장 모양을 새로 만들 때 순항 상태(속도·돌진)를 이어 준다.
  static void carry(TopGeometry from, TopGeometry to) {
    final s = _states[from];
    if (s != null) _states[to] = s;
  }

  /// 이번 틱 배 자리(바다 가운데에서 옮긴 값)와 머리. 보스전(비켜서기가 맡음)이면 멈춰 지금 자리 그대로.
  ({double x, double y, double heading}) step(Field f, TopGeometry g, {required bool fever, required double dt}) {
    final st = _states[g] ??= _CruiseState();
    final cur = (x: g.top.shipX - g.base.shipX, y: g.top.shipY - g.base.shipY);
    if (st.tick == f.tick) return (x: cur.x, y: cur.y, heading: st.heading);
    st.tick = f.tick;
    if (f.bossActive && f.fastSail == null) {
      st
        ..vx = 0
        ..vy = 0
        ..dashLeft = 0
        ..returning = false; // 보스전 뒤 제자리 복귀는 결투 비켜서기(TopDuel)가 예전처럼 맡는다
      return (x: cur.x, y: cur.y, heading: g.shipHeading);
    }
    // feverOnly(사용자 결정 2026-10-17 '배는 피버 타임일 때만 움직이는 게 낫겠어'): 평소엔 제자리(0) — 피버가 막 끝났으면
    // 같은 조향으로 감속하며 돌아와 settleDist 안에서 정확히 0에 선다(순간이동 없음).
    final rest = c.raw['feverOnly'] == true && !fever;
    if (rest && !st.returning) return (x: 0.0, y: 0.0, heading: 0.0);
    if (!rest) st.returning = true;
    if (rest) st.dashLeft = 0;
    st.sec += dt * (fever ? c.number('feverSpeedMul') : 1); // 피버면 8자도 빨리
    final fast = fever ? c.number('feverSpeedMul') : 1.0;
    final every =
        (c.number('dashEverySec') + c.number('dashJitterSec') * st.jitter) * (fever ? c.number('feverDashMul') : 1);
    st.sinceDash += dt;
    if (!rest && st.dashLeft <= 0 && st.sinceDash >= every) {
      final hit = _cluster(f, g, cur);
      st
        ..sinceDash = 0
        ..jitter = (st.jitter + c.number('jitterStep')) % 1;
      if (hit != null) {
        st
          ..dashLeft = c.number('dashMaxSec')
          ..tx = hit.x
          ..ty = hit.y;
      }
    }
    final dashing = st.dashLeft > 0;
    final target = rest ? (x: 0.0, y: 0.0) : (dashing ? _clamp(st.tx, st.ty) : _wander(st.sec));
    final top = speed * fast * (dashing ? c.number('dashSpeedMul') : 1);
    final dx = target.x - cur.x;
    final dy = target.y - cur.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (dashing) {
      st.dashLeft -= dt;
      if (d <= c.number('arriveRadius')) st.dashLeft = 0; // 지나쳤다 → 순항으로(감속하며 호를 그려 돌아간다)
    }
    // 원하는 속력: 도착 반경(slowRadius) 안에선 줄인다. 속력은 accel(올림)·decel(내림)까지, 방향은 초당 turn까지.
    final want = math.min(top, top * d / c.number('slowRadius'));
    var v = math.sqrt(st.vx * st.vx + st.vy * st.vy);
    v = want > v ? math.min(want, v + c.number('accel') * dt) : math.max(want, v - c.number('decel') * dt);
    final wantDir = d > 0 ? math.atan2(dy, dx) : st.dir;
    final dir = st.vx == 0 && st.vy == 0 ? wantDir : _turnToward(math.atan2(st.vy, st.vx), wantDir, turn * dt);
    v = math.min(v, _brake(cur, dir)); // 벽(rect) 쪽이면 남은 거리에 멈출 수 있게 속력만 줄인다 — 박혀서 꺾이지 않게
    st
      ..dir = dir
      ..vx = math.cos(dir) * v
      ..vy = math.sin(dir) * v;
    var nx = cur.x + st.vx * dt;
    var ny = cur.y + st.vy * dt;
    final r = c.obj('rect');
    if (nx.abs() > r.number('x')) {
      nx = nx.clamp(-r.number('x'), r.number('x'));
      st.vx = 0;
    }
    if (ny < -r.number('up') || ny > r.number('down')) {
      ny = ny.clamp(-r.number('up'), r.number('down'));
      st.vy = 0;
    }
    if (rest && math.sqrt(nx * nx + ny * ny) <= c.number('settleDist')) {
      nx = 0;
      ny = 0;
      st
        ..vx = 0
        ..vy = 0;
    }
    // 머리: 바다가 아래로 흐르니(배는 늘 앞으로) 진행 방향에 forwardFlow를 더해 기울기만 — 뒤돌아 서지 않는다.
    final face = math.atan2(st.vx, c.number('forwardFlow') - st.vy).clamp(-maxTilt, maxTilt);
    st.heading = _turnToward(st.heading, face, headingTurn * dt);
    if (rest && nx == 0 && ny == 0 && st.heading == 0) st.returning = false; // 제자리 도착 — 다음 피버까지 가만히
    return (x: nx, y: ny, heading: st.heading);
  }

  /// [dir]로 갈 때 rect 벽까지 남은 거리에서 decel로 멈출 수 있는 속력(√(2·decel·거리) ÷ 그 축 성분).
  double _brake(({double x, double y}) at, double dir) {
    final r = c.obj('rect');
    final ux = math.cos(dir);
    final uy = math.sin(dir);
    final room = (
      x: ux > 0 ? r.number('x') - at.x : r.number('x') + at.x,
      y: uy > 0 ? r.number('down') - at.y : r.number('up') + at.y,
    );
    final stop = c.number('decel') * (1 + 1);
    var cap = double.infinity;
    if (ux != 0) cap = math.min(cap, math.sqrt(stop * math.max<double>(0, room.x)) / ux.abs());
    if (uy != 0) cap = math.min(cap, math.sqrt(stop * math.max<double>(0, room.y)) / uy.abs());
    return cap;
  }

  /// 순항 목표: 집 자리 둘레 8자(가로 wanderX, 세로 wanderY — wanderSec 한 바퀴).
  ({double x, double y}) _wander(double sec) {
    final u = fullTurn * sec / c.number('wanderSec');
    return _clamp(c.number('wanderX') * math.sin(u), -c.number('homeUp') - c.number('wanderY') * math.sin(u + u));
  }

  ({double x, double y}) _clamp(double x, double y) {
    final r = c.obj('rect');
    return (x: x.clamp(-r.number('x'), r.number('x')), y: y.clamp(-r.number('up'), r.number('down')));
  }

  /// 카메라 안 잡몹 중 clusterRadius 안 이웃이 가장 많은 무리 → 지금 자리에서 그 무리 가운데를 지나 overshoot만큼 더 간 자리.
  ({double x, double y})? _cluster(Field f, TopGeometry g, ({double x, double y}) cur) {
    final hw = g.top.viewWidth * half;
    final hh = g.top.viewHeight * half;
    final mobs = [
      for (final e in f.foes)
        if (e.alive &&
            !e.boss &&
            e.holdSec <= 0 &&
            (e.x - g.base.shipX).abs() <= hw &&
            (e.y - g.base.shipY).abs() <= hh)
          (x: e.x - g.base.shipX, y: e.y - g.base.shipY),
    ];
    final r2 = c.number('clusterRadius') * c.number('clusterRadius');
    var best = c.number('clusterMin') - 1;
    ({double x, double y})? at;
    for (final a in mobs) {
      var n = 0;
      var sx = 0.0;
      var sy = 0.0;
      for (final b in mobs) {
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        if (dx * dx + dy * dy > r2) continue;
        n++;
        sx += b.x;
        sy += b.y;
      }
      if (n > best) {
        best = n.toDouble();
        at = (x: sx / n, y: sy / n);
      }
    }
    if (at == null) return null;
    final dx = at.x - cur.x;
    final dy = at.y - cur.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d == 0) return at;
    final over = c.number('overshoot');
    return (x: at.x + dx / d * over, y: at.y + dy / d * over);
  }

  static double _turnToward(double from, double to, double step) {
    var diff = to - from;
    diff = math.atan2(math.sin(diff), math.cos(diff));
    return diff.abs() <= step ? to : from + diff.sign * step;
  }
}

final _states = Expando<_CruiseState>('topCruiseState');

/// 전장 모양 하나의 순항 상태.
class _CruiseState {
  double vx = 0;
  double vy = 0;
  double dir = 0;
  double heading = 0;
  double sec = 0;
  double sinceDash = 0;
  double jitter = 0;
  double dashLeft = 0;
  double tx = 0;
  double ty = 0;
  int tick = -1;
  bool returning = false; // 피버 순항 뒤 제자리로 돌아가는 중(feverOnly)
}
