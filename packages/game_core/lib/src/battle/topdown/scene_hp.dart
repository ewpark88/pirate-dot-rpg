import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/offline.dart' show fleetDps;
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 장면 적 HP 위 막기(S2 2026-10-18): max(지금 스테이지 기준 HP, 출전 함대 초당 피해 × [sec] × dpsHpRatio).
/// 약한 함대는 스테이지가 정하고(오래 걸림 = 강화할 이유), 센 함대만 'DPS × 목표 초'로 위가 막혀 0초 기록·끝없는 판이 없어진다.
/// [cfg]에 dpsHpRatio가 없거나 [sec]가 0이면 [stageHp] 그대로.
BigNum sceneHp(GameState s, GameTables t, JsonReader cfg, List<String> fleet, BigNum stageHp, double sec) {
  final ratio = cfg.numberOr('dpsHpRatio', 0);
  if (ratio <= 0 || sec <= 0) return stageHp;
  return BigNum.max(stageHp, fleetDps(s, t, fleet).times(sec * ratio));
}
