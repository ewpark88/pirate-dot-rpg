import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_data/game_data.dart';

/// 맞은 적 하나와 그 적이 받는 피해 비율(연쇄·관통 감쇠, 범위 초과 50% 반영).
typedef Hit = ({Foe foe, double factor});

/// 공격 한 번의 결과. `x`,`y`는 조준점(렌더가 발사체를 날리는 곳).
typedef Volley = ({double x, double y, List<Hit> hits});

/// [a]의 사거리(skills.json `reach`, 탑다운은 배 둘레 → 적 가장자리 거리). 없으면 null = 보이는 화면 전체.
double? attackReach(AttackDef a, FieldDef f) => a.raw.has('reach') ? a.raw.number('reach') : null;

/// 맞은 순서대로 피해 비율을 붙인다: 연쇄·관통은 한 번마다 `chainFalloff` 감소,
/// `aoe.fullDamageTargets`를 넘은 적은 `aoe.overflowDamage` (설계서 4.8).
List<Hit> spread(List<Foe> hit, WavesTable w, {bool falloff = false}) => [
  for (var i = 0; i < hit.length; i++)
    (
      foe: hit[i],
      factor:
          (falloff ? math.pow(1 - w.chainFalloff, i).toDouble() : 1.0) *
          (i >= w.aoeFullDamageTargets ? w.aoeOverflowDamage : 1.0),
    ),
];
