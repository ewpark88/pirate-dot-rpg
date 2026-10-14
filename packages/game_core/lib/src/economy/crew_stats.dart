import 'dart:math' as math;

import 'package:game_data/game_data.dart';

// 선원 레벨 → 등급·파워 배율 (설계서 4.3.1). 전투 레인이 그대로 부른다.

/// [level]이 속한 등급 (rarities.json 레벨 구간).
RarityDef rarityOfLevel(RarityTable t, int level) =>
    t.rarities.firstWhere((r) => level <= r.levelMax, orElse: () => t.rarities.last);

/// [level]까지 거친 승급 횟수 = 등급 순번(일반 0 … 신화 4).
int promotionCount(RarityTable t, int level) => t.rarities.indexOf(rarityOfLevel(t, level));

/// 선원 파워 배율 `(1 + powerPerLevel × (Lv − 1)) × promotionMultiplier^승급`. 기본 파워에 곱한다.
double crewPowerMultiplier(GrowthTable g, RarityTable t, int level) =>
    (1 + g.powerPerLevel * (level - 1)) * math.pow(g.promotionMultiplier, promotionCount(t, level));
