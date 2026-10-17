import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/battle/topdown/top_fever_flow.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/economy/fever.dart' show feverOn;
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 피버 오라 (사용자 지시 '피버 동안 배가 빠르게 나아가며 주변 적을 녹인다', 표 meta.fever.aura — S2).
/// 피버 중 배 중심에서 반경 = 배 반경 × radiusShipMul 안의 적에게 pulseSec마다 피해:
/// 한 펄스 = 그 스테이지 잡몹 한 마리 HP × (pulseSec ÷ waveHpPerSec) — waveHpPerSec초면 닿은 잡몹이 녹는다. 보스는 × bossFactor.
/// 표에 aura가 없으면 아무것도 하지 않는다. 처치·골드·숫자는 보통 공격과 같은 길(strike, 선원 없음).
extension FeverAura on Round {
  void feverAura(GameState s) {
    final fever = t.meta.raw.obj('fever');
    final g = geo;
    if (!fever.has('aura') || !feverOn(s) || g is! TopGeometry) return;
    final a = fever.obj('aura');
    final pulse = math.max(1, (a.numberOr('pulseSec', dt) / dt).round());
    if (ctx.tick % pulse != 0) return;
    final radius = g.top.shipRadius * a.number('radiusShipMul');
    final stage = field.stage;
    final share = w.mobPoolAt(stage) / w.topMobCountAt(stage);
    final mobHp = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor * share);
    final perPulse = mobHp.times(pulse * dt / a.number('waveHpPerSec'));
    final bossFactor = a.numberOr('bossFactor', 1);
    final hits = [
      for (final e in field.living)
        if (e.holdSec <= 0 && e.eventKind != 'goldfish' && _within(g, e, radius))
          (foe: e, factor: e.boss ? bossFactor : 1.0),
    ];
    if (hits.isEmpty) return;
    strike((x: g.top.shipX, y: g.top.shipY, hits: hits), perPulse);
  }

  static bool _within(TopGeometry g, Foe e, double radius) {
    final dx = e.x - g.top.shipX;
    final dy = e.y - g.top.shipY;
    final r = radius + g.top.radiusOf(e);
    return dx * dx + dy * dy <= r * r;
  }
}

/// 피버 중 '배가 전진하는 느낌': 배 앞쪽(위)에서 오는 적이 더 빨리 다가온다 — meta.fever.aura.forwardBoost(없으면 0).
/// [on]이 주어지면 피버 대신 그 값(빠른 항해 돌파 중에도 켠다).
double feverForwardBoost(GameState s, Map<String, Object?> feverRaw, {bool? on}) {
  final aura = feverRaw['aura'];
  if (aura is! Map || !(on ?? feverOn(s))) return 0;
  return (aura['forwardBoost'] as num?)?.toDouble() ?? 0;
}

/// 피버 좌우 이동(사용자 지시 '피버 때 배가 좌우로 멋지게', '지그재그로 대각선', '조금 더 느리게' — meta.fever.weave):
/// 배 중심의 옮김(x 좌우·y 앞뒤)과 기울기(heading, 라디안 — 0 위, 시계 방향). 키가 없거나 피버(·[on])가 아니면 0.
/// - mode 'flow'(amp, ampY, periodSec, tiltDeg, drift, loopEvery·loopRadius·loopSec): 매끈한 8자 곡선 + 가끔 작은 원(top_fever_flow.dart, #24).
/// - mode 'zigzag'(amp, legSec, turnSec, surge, tiltDeg): x는 한 다리(legSec) 동안 일정 속도로 가로지르고 끝에서 turnSec 동안
///   부드럽게 꺾는다(꼭짓점 = ±amp). 다리마다 y는 앞으로 surge만큼 나갔다 돌아온다. 기울기 = tiltDeg × (x 속도 ÷ 다리 속도).
/// - 그 밖(사인): amp × sin(한 바퀴 × 초 ÷ periodSec), 기울기 0.
/// 시작·끝은 부드럽게(한 다리 또는 반 주기 동안 코사인 ease, 끝은 남은 피버 틱으로).
({double x, double y, double heading}) feverPose(GameState s, GameTables t, int tick, {bool? on}) {
  const still = (x: 0.0, y: 0.0, heading: 0.0);
  final fever = t.meta.raw.obj('fever');
  if (!fever.has('weave') || !(on ?? feverOn(s))) return still;
  final w = fever.obj('weave');
  final dt = t.waves.tickMs * secondsPerMillisecond;
  final amp = w.number('amp');
  final zig = w.raw['mode'] == 'zigzag';
  final flow = w.raw['mode'] == 'flow';
  final ramp = zig ? w.number('legSec') : w.number('periodSec') * half;
  final left = feverOn(s) ? s.battle!.feverTicksLeft : tick;
  final edge = math.min(tick, left) * dt / ramp; // 0~1: 시작·끝에서 얼마나 떨어졌나
  final ease = edge >= 1 ? 1.0 : (1 - math.cos(math.pi * edge)) * half;
  if (flow) return flowPose(w, tick * dt, ease, dt);
  if (!zig) return (x: amp * math.sin(math.pi / half * tick * dt / w.number('periodSec')) * ease, y: 0.0, heading: 0.0);
  final leg = w.number('legSec');
  final turn = w.number('turnSec');
  final v = amp / (leg * half + turn / math.pi); // 다리 속도: 꺾는 동안 v·turn/π만큼 더 가서 꼭짓점이 amp
  final line = v * leg * half; // 곧게 가는 끝
  final bend = v * turn / math.pi;
  final cycle = (leg + turn) / half;
  final at = (tick * dt + leg * half) % cycle; // 가운데에서 오른쪽으로 출발
  double x;
  double vx;
  var y = 0.0;
  if (at < leg) {
    x = -line + v * at;
    vx = v;
    y = -w.numberOr('surge', 0) * math.sin(math.pi * at / leg);
  } else if (at < leg + turn) {
    final u = at - leg;
    x = line + bend * math.sin(math.pi * u / turn);
    vx = v * math.cos(math.pi * u / turn);
  } else if (at < leg + turn + leg) {
    final u = at - leg - turn;
    x = line - v * u;
    vx = -v;
    y = -w.numberOr('surge', 0) * math.sin(math.pi * u / leg);
  } else {
    final u = at - leg - turn - leg;
    x = -line - bend * math.sin(math.pi * u / turn);
    vx = -v * math.cos(math.pi * u / turn);
  }
  final tilt = w.numberOr('tiltDeg', 0) * radiansPerDegree;
  return (x: x * ease, y: y * ease, heading: tilt * vx / v * ease);
}

/// 피버 좌우 이동의 x만(사인 시절 이름 — 테스트·호환).
double feverWeave(GameState s, GameTables t, int tick, {bool? on}) => feverPose(s, t, tick, on: on).x;
