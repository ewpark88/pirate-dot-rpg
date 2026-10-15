import 'package:game_core/src/economy/meta_views.dart';
import 'package:game_core/src/economy/rebirth.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 보유 효과 (설계서 4.3): 보유 선원마다 Lv × `growth.ownedBonusPerLevel`. 출전하지 않은 선원도 센다.
double ownedBonus(GameState s, GameTables t) {
  var levels = 0;
  for (final c in s.crews.values) {
    levels += c.level;
  }
  return levels * t.growth.ownedBonusPerLevel;
}

/// 설계서 4.8 최종 피해의 ‘마지막 % 합’ 중 경제 몫: 환생 조각 + 보유 효과 + 도감. 전투(CombatStats)와 오프라인 추정이 같은 값을 쓴다.
double damageBonus(GameState s, GameTables t) =>
    rebirthBonus(s, t) + ownedBonus(s, t) + collectionBonus(s, t).attackBonus;
