import 'package:game_data/src/models/common.dart';

/// 잡몹 한 종류. 보스(`RegionDef.boss`)는 여기에 없고 waves.json의 boss 배율을 쓴다.
class EnemyDef {
  EnemyDef.fromJson(JsonReader j)
    : id = j.str('id'),
      layer = j.str('layer'),
      hpScale = j.number('hpScale'),
      speed = j.number('speed'),
      role = j.str('role'),
      splitInto = j.strOrNull('splitInto'),
      splitCount = j.intOrNull('splitCount') ?? 0,
      splitHpRatio = j.numberOr('splitHpRatio', 0),
      reviveHpRatio = j.numberOr('reviveHpRatio', 0),
      ranged = j.has('ranged') ? j.obj('ranged') : null,
      bomber = j.has('bomber') ? j.obj('bomber') : null,
      swarmCount = j.intOrNull('swarmCount') ?? 0;

  final String id;

  /// surface | underwater | air.
  final String layer;
  final double hpScale;

  /// 초당 이동 거리(논리 px).
  final double speed;

  /// 역할 (설계서 4.11): basic, fast, tough, air, split, revive. 배율은 speed·hpScale에, 역할은 특수 동작만.
  final String role;

  /// 분열: 처치되면 [splitInto]를 [splitCount]마리, 체력 = 부모 최대 체력 × [splitHpRatio].
  final String? splitInto;
  final int splitCount;
  final double splitHpRatio;

  /// 부활: 처음 처치되면 체력 [reviveHpRatio]로 한 번 일어난다.
  final double reviveHpRatio;

  /// 원거리 공격(배 위협 (a), 선택): {range, intervalSec, damageRatio, projectileSpeed, kind}. 없으면 접촉만.
  final JsonReader? ranged;

  /// 도감 v2 자폭(선택): {capMul, blastRadius, blastRatio} — 배에 닿으면 터져 한 대 상한 × capMul 피해 후 사라짐(보상 없음),
  /// 먼저 잡히면 반경 안 적에게 최대 HP × blastRatio.
  final JsonReader? bomber;

  /// 도감 v2 떼(선택): 한 마리 자리에 이 수만큼 작은 적(HP·골드·공격 ÷ 수). 0이면 보통.
  final int swarmCount;
}
