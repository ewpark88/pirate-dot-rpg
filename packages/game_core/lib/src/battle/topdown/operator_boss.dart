import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show startBoss;
import 'package:game_core/src/economy/rebirth_shop.dart' show bossExtraSec;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';

/// 운영자 보스 명령(설계서 6.10 '오늘 새 기능을 폰에서 바로'): 보스 소환([OpSpawnBoss.bossId]면 그 보스 — 특성 보스 시험) ·
/// 브레이크 게이지 가득([OpBossBreak] — 다음 틱 tickBossBreak가 쓰러뜨린다). 바뀐 전장을 돌려준다.
Field operatorBoss(Field f, GameState s, SystemContext ctx, OperatorCommand c) {
  switch (c) {
    case OpSpawnBoss(:final bossId):
      f.foes.clear();
      final def = bossId == null ? null : ctx.tables.regions.bosses[bossId];
      startBoss(f, s.progress.stage, ctx, extraSec: bossExtraSec(s, ctx.tables), bossDef: def);
    case OpBossBreak():
      if (!ctx.tables.skills.raw.has('bossBreak')) break; // 표에 브레이크가 없으면(꺼짐) 아무 일 없음
      for (final e in f.living) {
        if (e.boss) e.breakGauge = 1;
      }
    default:
  }
  return f;
}
