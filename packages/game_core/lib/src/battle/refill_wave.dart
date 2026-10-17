import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart'
    show feverSwarmPattern, hordeCountAt, spawnWave, startBoss, tutorialBossScale;
import 'package:game_core/src/economy/fever.dart' show feverJustStarted, feverOn;
import 'package:game_core/src/economy/rebirth_shop.dart' show fastSailFraction;
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';

/// 보충 파(사용자 목표 '우수수 쓸리는 쾌감' — 실기기 스테이지 30 파밍에 화면 적 1~2마리, S1 2026-10-17): 무리가 한 파의
/// `top.refill.belowRatio`(최소 `min`마리) 아래로 줄면 다음 파를 바로 부르고, 앞 파를 '잡은 파'로 센다(파마다 한 번씩 — 남은 무리는
/// 섞여서 계속 싸운다). 보스 차례 직전(다음이 보스)·보스전·장면 콘텐츠·빠른 항해·출항 대기 중엔 안 한다.
/// 피버 중엔 고리가 `fever.swarm.refillBelow`마리 아래로 줄면 고리를 또 부른다(초반엔 고리가 몇 초 만에 쓸려 남은 피버가 빈 바다였다)
/// — 보스 차례 직전에도, 파로 세지 않고.
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
  if (f.bossActive) return s;
  final sw = t.meta.raw.obj('fever').obj('swarm');
  // 피버는 다 녹아 0마리여도 바로 다음 고리(평소처럼 이동 시간을 기다리면 피버 중 빈 바다 — 실기기 7-2 2026-10-17).
  if (feverOn(s)) {
    // 피버 고리 보충은 덤 — 파로 세지 않는다(세면 마지막 파에 금방 닿아 보스 차례라 멈추고, 진행만 빨라진다).
    if (left > (sw.intOrNull('refillBelow') ?? 0)) return s;
    f
      ..feverSwarm = feverSwarmPattern(t, fever: true)
      ..poolScale = sw.numberOr('refillPool', 1); // 보충 고리는 한 파 몫의 일부(HP·골드·공격)
    spawnWave(f, p.stage, ctx);
    f
      ..feverSwarm = null
      ..poolScale = 1;
    return s;
  }
  if (left == 0) return s;
  final per = fast ? w.rebirthSkip.waves : w.wavesPerStage;
  if (!p.farming && p.wave + 1 >= per) return s; // 이 파가 마지막 — 다 잡으면 보스
  final r = w.raw.obj('top').obj('refill');
  if (p.stage < (r.intOrNull('fromStage') ?? 0)) return s; // 초반(무리 덤)은 이미 빽빽 — 진행 속도 그대로
  final below = math.max(r.integer('min'), (w.topMobCountAt(p.stage) * r.number('belowRatio')).round());
  if (left > below) return s;
  spawnWave(f, p.stage, ctx);
  final wave = p.wave < per ? p.wave + 1 : p.wave;
  ctx.emit(WaveCleared(ctx.tick, wave: wave));
  return s.copyWith(progress: p.copyWith(wave: wave));
}

/// 빠른 항해 구간(환생 뒤 bestStage × fastSailFraction 이하) — battle_system에서 옮김(300줄).
bool fastSailing(GameState s, SystemContext ctx) =>
    s.progress.rebirths > 0 && s.progress.stage <= (s.progress.bestStage * fastSailFraction(s, ctx.tables)).ceil();

/// 무리 다음은 무리, 파를 다 잡았고 파밍 중이 아니면 보스. 빠른 항해: 환생 뒤 bestStage × fastSailFraction(올림) 이하는 rebirthSkip.waves개만.
void nextEncounter(Field f, GameState s, SystemContext ctx) {
  final p = s.progress;
  if (p.sailHold) return; // 환생 뒤 출항 대기: 잔잔한 바다(#19)
  final w = ctx.tables.waves;
  final fast = fastSailing(s, ctx);
  if (!p.farming && p.wave >= (fast ? w.rebirthSkip.waves : w.wavesPerStage)) {
    startBoss(f, p.stage, ctx, hpScale: tutorialBossScale(s, ctx.tables));
  } else {
    // 대군 습격(사용자 2026-10-17 '스테이지를 넘어갈 때마다 많이 몰려들게'): 스테이지 첫 파(파밍 아님)는 hordeCountAt마리가
    // 사방(고리)에서 한꺼번에 — 한 파 몫은 그대로 나눈다(처치 시간·골드 총량 같음).
    final horde = !p.farming && p.wave == 0 && hordeCountAt(ctx.tables, p.stage) > 0 && !feverOn(s);
    f
      ..feverSwarm = horde ? 'ring' : feverSwarmPattern(ctx.tables, fever: feverOn(s))
      ..hordeCount = horde ? hordeCountAt(ctx.tables, p.stage) : 0;
    spawnWave(f, p.stage, ctx);
    f
      ..feverSwarm = null
      ..hordeCount = 0;
    if (horde) ctx.emit(HordeIncoming(ctx.tick, stage: p.stage, count: hordeCountAt(ctx.tables, p.stage)));
  }
}
