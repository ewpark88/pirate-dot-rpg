import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/fever.dart' show addFever, feverOn;
import 'package:game_core/src/economy/gold_cap.dart';
import 'package:game_core/src/economy/offline.dart';
import 'package:game_core/src/economy/sea_events.dart' show seaEventStep;
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

// 즉석 도전 (docs/specs/platform-fun-fever.md B). 수치는 meta.challenges.
// 실패해도 잃는 것 없음 — 띠가 조용히 사라진다. 진행 중 도전은 저장하지 않는다(다음까지 남은 시간만 progress.challengeInSec).

JsonReader _cfg(GameTables t) => t.meta.raw.obj('challenges');
JsonReader _kind(GameTables t, String id) => _cfg(t).objs('kinds').firstWhere((k) => k.str('id') == id);

/// BattleSystem이 하나 들고 매 틱 부른다: 처치율(최근 rateWindowSec 평균)과 피격을 보고, 돌발 이벤트·도전을 한 번에 진행한다.
class ChallengeTracker {
  double _killRate = 0;
  BigNum _lost = BigNum.zero;
  int _lostTicks = 0;

  /// 전투 골드가 화물칸에서 넘친 몫을 모아 overflowSec마다 GoldOverflow 한 번(렌더 '화물칸 가득!').
  void overflow(BigNum lost, SystemContext ctx) {
    if (!lost.isZero) _lost = _lost + lost;
    final every =
        ctx.tables.meta.raw.obj('cargo').number('overflowSec') / (ctx.tables.waves.tickMs * secondsPerMillisecond);
    if (_lost.isZero || ++_lostTicks < every.round()) return;
    ctx.emit(GoldOverflow(ctx.tick, lost: _lost));
    _lost = BigNum.zero;
    _lostTicks = 0;
  }

  BigNum? _lastHp;

  /// 처치율 추정(초당). 목표치 계산·테스트용.
  double get killRate => _killRate;

  GameState step(GameState s, Field f, SystemContext ctx, {required int kills}) {
    final t = ctx.tables;
    final dt = t.waves.tickMs * secondsPerMillisecond;
    _killRate += (kills / dt - _killRate) * math.min(dt / _cfg(t).number('rateWindowSec'), 1);
    final hit = _lastHp != null && f.shipHp < _lastHp!;
    _lastHp = f.shipHp;
    final multi = f.multiKill;
    f.multiKill = 0;
    var next = seaEventStep(s, f, ctx);
    if (next.progress.stage < _cfg(t).integer('minStage')) return next;
    // 간격은 시작→시작: 도전 중·미루는 중에도 줄어들고, 0 이하면 미룰 이유가 없어지는 대로 시작.
    // 첫 간격은 난수 없이 표 최솟값 — 전투 난수 순서를 바꾸지 않게(선원 균형 측정이 난수 순서에 민감).
    final first = ((_cfg(t).raw['intervalSec'] as List).first as num).toDouble();
    final left = (next.progress.challengeInSec ?? first) - dt;
    next = next.copyWith(progress: next.progress.copyWith(challengeInSec: left));
    final c = next.battle?.challenge;
    if (c != null) return _tick(next, ctx, c, kills: kills, multi: multi, hit: hit);
    if (left > 0 || f.bossActive || feverOn(next) || next.battle?.seaEvent != null) return next;
    return _start(next, ctx);
  }

  GameState _start(GameState s, SystemContext ctx) {
    final t = ctx.tables;
    final pool = _cfg(t).objs('kinds');
    final total = pool.fold<double>(0, (a, k) => a + k.number('weight'));
    var r = ctx.rng.nextDouble() * total;
    var kind = pool.last;
    for (final k in pool) {
      r -= k.number('weight');
      if (r < 0) {
        kind = k;
        break;
      }
    }
    final sec = kind.number('sec');
    final target = switch (kind.str('id')) {
      'kills' => math.max((_killRate * sec * kind.number('targetFactor')).ceil(), 1),
      'combo' => kind.integer('times'),
      _ => sec.round(), // noHit
    };
    final ticks = (sec / (t.waves.tickMs * secondsPerMillisecond)).round();
    ctx.emit(ChallengeStarted(ctx.tick, id: kind.str('id'), target: target, untilTick: ctx.tick + ticks));
    return s.copyWith(
      progress: s.progress.copyWith(challengeInSec: _between(ctx, _cfg(t).raw['intervalSec'] as List)),
      battle: (s.battle ?? BattleView.empty).copyWith(
        challenge: ChallengeView(id: kind.str('id'), target: target, value: 0, ticksLeft: ticks),
      ),
    );
  }

  GameState _tick(
    GameState s,
    SystemContext ctx,
    ChallengeView c, {
    required int kills,
    required int multi,
    required bool hit,
  }) {
    final t = ctx.tables;
    final kind = _kind(t, c.id);
    final ticksPerSec = 1 / (t.waves.tickMs * secondsPerMillisecond);
    final left = c.ticksLeft - 1;
    final value = switch (c.id) {
      'kills' => c.value + kills,
      'combo' => c.value + (multi >= kind.integer('multiKill') ? 1 : 0),
      _ => ((c.target * ticksPerSec - left) / ticksPerSec).floor(), // noHit
    };
    if (c.id == 'noHit' && hit) return _end(s, ctx, c, success: false);
    if (value != c.value && c.id != 'noHit') ctx.emit(ChallengeProgress(ctx.tick, id: c.id, value: value));
    if (c.id != 'noHit' && value >= c.target) return _end(s, ctx, c, success: true);
    if (left <= 0) return _end(s, ctx, c, success: c.id == 'noHit');
    return s.copyWith(
      battle: s.battle!.copyWith(
        challenge: ChallengeView(id: c.id, target: c.target, value: value, ticksLeft: left),
      ),
    );
  }

  GameState _end(GameState s, SystemContext ctx, ChallengeView c, {required bool success}) {
    final t = ctx.tables;
    var next = s.copyWith(battle: s.battle?.copyWith(clearChallenge: true));
    String? reward;
    if (success) {
      final r = _kind(t, c.id).obj('reward');
      switch (r.str('type')) {
        case 'goldMinutes':
          final gold = goldPerSecEstimate(
            s,
            t,
            offlineFleet(s, t),
          ).times(r.number('value') * Duration.secondsPerMinute);
          next = grantGold(next, ctx, gold);
          reward = 'gold:$gold';
        case 'fever':
          next = next.copyWith(progress: next.progress.copyWith(fever: next.progress.fever + r.number('value')));
          reward = 'fever:${r.number('value')}';
        default:
          next = next.copyWith(wallet: next.wallet.copyWith(gems: next.wallet.gems + r.integer('value')));
          reward = 'gems:${r.integer('value')}';
      }
    }
    ctx.emit(ChallengeEnded(ctx.tick, id: c.id, success: success, reward: reward));
    return success ? addFever(next, t.meta.raw.obj('fever').number('challengeWin')) : next;
  }
}

double _between(SystemContext ctx, List<dynamic> range) {
  final lo = (range[0] as num).toDouble();
  final hi = (range[1] as num).toDouble();
  return lo + ctx.rng.nextDouble() * (hi - lo);
}
