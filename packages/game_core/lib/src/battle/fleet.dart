import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 자동 편성 (설계서 4.3·4.8): 파워 내림차순(같으면 crews.json 순서),
/// 같은 계열은 최대 `maxSameFamilyInFleet`명, [slots]명까지.
List<String> autoFleet(GameState s, GameTables t, int slots) {
  final owned = [
    for (final c in t.crews.crews)
      if (s.crews[c.id] case final st?) (def: c, power: crewPower(t, st.level)),
  ]..sort((a, b) => a.power != b.power ? b.power.compareTo(a.power) : a.def.num.compareTo(b.def.num));
  final perFamily = <String, int>{};
  final out = <String>[];
  for (final c in owned) {
    if (out.length >= slots) break;
    final n = perFamily[c.def.family] ?? 0;
    if (n >= t.skills.maxSameFamilyInFleet) continue;
    perFamily[c.def.family] = n + 1;
    out.add(c.def.id);
  }
  return out;
}

/// 선장 = 출전 선원 중 등급이 가장 높은 선원. 같으면 편성 순서(파워 순)가 앞선 쪽.
String? captainOf(List<String> fleet, GameState s, GameTables t) {
  String? best;
  var bestRarity = -1;
  for (final id in fleet) {
    final r = rarityIndexAt(t.rarities, s.crews[id]?.level ?? 1);
    if (r > bestRarity) {
      best = id;
      bestRarity = r;
    }
  }
  return best;
}
