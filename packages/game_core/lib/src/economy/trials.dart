import 'package:game_core/src/economy/ads.dart' show addTailwind, autoUpgradeRemaining;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 맛보기(meta.trials, 사용자 요청 2026-10-17 '초기 유입 사용자가 2배속·자동 강화를 맛보게'): 계정당 1회씩 무료 버프.
/// - speed: 최고 스테이지 `atStage` 이상이면 순풍(2배속 + 골드 2배, ads tailwind 효과 그대로) `durationSec`
/// - autoUpgrade: 보스 실패 `afterBossFails`번 이상이면 자동 강화(+ 자동 합성, auto_upgrade.dart) `durationSec`
/// 끝나면 화면이 '광고로 10분 더(ads tailwind·autoUpgrade) / 유료 영구(IAP)'로 잇는다(docs/specs/economy-iap.md).
bool trialReady(GameState s, GameTables t, String kind) {
  final m = t.meta.raw;
  if (!m.has('trials') || !m.obj('trials').has(kind) || s.progress.trialsUsed.contains(kind)) return false;
  final c = m.obj('trials').obj(kind);
  final p = s.progress;
  return p.bestStage >= (c.intOrNull('atStage') ?? 0) && p.bossFails >= (c.intOrNull('afterBossFails') ?? 0);
}

/// 받을 수 있는 맛보기 종류(표 순서) — 화면 팝업이 첫 것을 띄운다.
List<String> trialsReady(GameState s, GameTables t) => [
  if (t.meta.raw.has('trials'))
    for (final k in t.meta.raw.obj('trials').raw.keys)
      if (trialReady(s, t, k)) k,
];

GameState claimTrial(GameState s, ClaimTrial c, SystemContext ctx) {
  final t = ctx.tables;
  if (!trialReady(s, t, c.kind)) return s;
  final sec = t.meta.raw.obj('trials').obj(c.kind).integer('durationSec');
  final now = ctx.clock.now();
  final d = Duration(seconds: sec);
  final granted = switch (c.kind) {
    'speed' => addTailwind(s, t, now, d),
    _ => s.copyWith(buffs: s.buffs.copyWith(autoUpgradeUntil: now.add(autoUpgradeRemaining(s, now) + d).toUtc())),
  };
  ctx
    ..emit(TrialClaimed(ctx.tick, kind: c.kind, seconds: sec))
    ..emit(SaveRequested(ctx.tick, reason: 'trial'));
  return granted.copyWith(progress: granted.progress.copyWith(trialsUsed: [...s.progress.trialsUsed, c.kind]));
}
