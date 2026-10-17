import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show feverSwarmPattern, spawnWave;
import 'package:game_core/src/economy/fever.dart' show feverJustStarted, feverOn;
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';

/// 보충 파(사용자 목표 '우수수 쓸리는 쾌감' — 실기기 스테이지 30 파밍에 화면 적 1~2마리, S1 2026-10-17): 무리가 한 파의
/// `top.refill.belowRatio`(최소 `min`마리) 아래로 줄면 다음 파를 바로 부르고, 앞 파를 '잡은 파'로 센다(파마다 한 번씩 — 남은 무리는
/// 섞여서 계속 싸운다). 보스 차례 직전(다음이 보스)·보스전·피버(이미 빽빽)·장면 콘텐츠·빠른 항해·출항 대기 중엔 안 한다.
GameState refillWave(GameState s, Field f, SystemContext ctx, {required bool fast}) {
  final t = ctx.tables;
  final w = t.waves;
  final p = s.progress;
  final left = f.waveFoes.length;
  if (f.inScene || f.fastSail != null || p.sailHold) return s;
  if (feverJustStarted(s, t) && !f.bossActive) {
    // 피버가 켜지는 틱: 앞 파가 남아 있어도 피버 무리(고리)를 바로 — 앞 파를 다 잡아야 나오면 피버 10초가 끝나도 안 왔다(S2 밀도).
    f.feverSwarm = feverSwarmPattern(t, fever: true);
    spawnWave(f, p.stage, ctx);
    f.feverSwarm = null;
    return s;
  }
  if (left == 0 || f.bossActive || feverOn(s)) return s; // 피버 중엔 보충 안 함(이미 빽빽)
  final per = fast ? w.rebirthSkip.waves : w.wavesPerStage;
  if (!p.farming && p.wave + 1 >= per) return s; // 이 파가 마지막 — 다 잡으면 보스
  final r = w.raw.obj('top').obj('refill');
  final below = math.max(r.integer('min'), (w.topMobCountAt(p.stage) * r.number('belowRatio')).round());
  if (left > below) return s;
  spawnWave(f, p.stage, ctx);
  final wave = p.wave < per ? p.wave + 1 : p.wave;
  ctx.emit(WaveCleared(ctx.tick, wave: wave));
  return s.copyWith(progress: p.copyWith(wave: wave));
}
