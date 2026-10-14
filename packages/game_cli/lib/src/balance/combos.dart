import 'dart:math' as math;

import 'package:game_data/game_data.dart';

/// 출전 인원 (화면 아래 슬롯 6칸).
const comboSize = 6;

/// 자동 편성 규칙(설계서 4.8): 같은 계열 최대 2명.
const maxSameFamily = 2;

/// 6명 조합 [n]개를 시드 고정으로 뽑는다. 같은 계열은 최대 2명, 같은 조합은 다시 뽑지 않는다.
List<List<String>> sampleCombos(GameTables t, int n, {required int seed}) {
  final rng = math.Random(seed);
  final crews = t.crews.crews;
  final seen = <String>{};
  final out = <List<String>>[];
  var guard = 0;
  final maxTries = n * 100;
  while (out.length < n && guard++ < maxTries) {
    final pool = [...crews]..shuffle(rng);
    final picked = <String>[];
    final perFamily = <String, int>{};
    for (final c in pool) {
      if ((perFamily[c.family] ?? 0) >= maxSameFamily) continue;
      perFamily[c.family] = (perFamily[c.family] ?? 0) + 1;
      picked.add(c.id);
      if (picked.length == comboSize) break;
    }
    if (picked.length < comboSize) continue;
    picked.sort();
    if (seen.add(picked.join(','))) out.add(picked);
  }
  return out;
}
