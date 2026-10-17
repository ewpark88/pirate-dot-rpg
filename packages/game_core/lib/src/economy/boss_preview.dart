import 'package:game_core/src/battle/spawner.dart' show bossAttack, bossMaxHp, tutorialBossScale;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/rebirth_rewards.dart' show treasureHpMultiplier;
import 'package:game_core/src/economy/rebirth_shop.dart' show bossExtraSec;
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 보스 비교 표시(S4 요청 ui-boss-compare, 피드백 #5 '보스 공격력 vs 내 공격력').
/// `maxHp`·`attack`은 전투(startBoss)와 같은 공식 — UI가 따로 베끼지 않게.
typedef BossPreview = ({String bossId, BigNum maxHp, BigNum attack, double timeLimitSec});

/// 지금 스테이지의 보스 — 파밍 중이면 다음에 부를 보스, 보스전 중이면 그 보스(같은 스테이지).
/// 튜토리얼 보스·보물 바다 체력 배율, 보물지도 상점 보스 시간까지 넣는다. 현상금 보스는 아니다.
BossPreview bossPreview(GameState s, GameTables t) {
  final stage = s.progress.stage;
  final def = t.regions.bossAt(stage);
  return (
    bossId: def.id,
    maxHp: bossMaxHp(t, stage, def: def, hpScale: tutorialBossScale(s, t) * treasureHpMultiplier(s, t)),
    attack: bossAttack(t.waves, stage),
    timeLimitSec: t.waves.bossTimeLimitSec + bossExtraSec(s, t),
  );
}
