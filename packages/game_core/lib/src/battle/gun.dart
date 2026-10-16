import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_data/game_data.dart';

/// 무기 슬롯 하나 (출전 선원).
class Gun {
  Gun({
    required this.crewId,
    required this.family,
    required this.power,
    required this.skill,
    this.rarity = 0,
    this.legend,
    JsonReader? aim,
    List<JsonReader> rankAims = const [],
    double tempo = 1,
  }) : attack = rankAims.fold(family.attackAt(rarity).overlay(aim), (a, r) => a.overlay(r)).tempo(tempo);

  /// [crewId]의 계열·등급 사다리·스킬(선원 `skill`이 있으면 그것)로 만든다.
  factory Gun.of(GameTables t, String crewId, {required double power, int rarity = 0}) {
    final crew = t.crews.byId(crewId);
    final family = t.skills.byId(crew.family);
    final skillId = crew.skill;
    int at(String id) => t.rarities.rarities.indexWhere((r) => r.id == id);
    final aim = crew.aim;
    final tempo = t.skills.rarityTempo;
    return Gun(
      crewId: crewId,
      family: family,
      power: power,
      rarity: rarity,
      skill: skillId == null ? family.skill : t.skills.skillById(skillId),
      legend: t.skills.legendFor(crewId, rarity, t.rarities.rarities.indexWhere((r) => r.id == 'legend')),
      aim: aim,
      // 등급별 덮어쓰기(S2): aim.legend는 전설 이상, aim.mythic은 신화 이상에서 그 위에 — 예 단일형 신화의 splashRadius
      rankAims: [
        for (final id in const ['legend', 'mythic'])
          if (aim != null && aim.has(id) && at(id) >= 0 && rarity >= at(id)) aim.obj(id),
      ],
      tempo: rarity < tempo.length ? tempo[rarity] : 1,
    );
  }

  final String crewId;
  final FamilyDef family;

  /// 선원 파워 (레벨 배율 × 승급 배율).
  final double power;

  /// 등급 순번 (0 = 일반). 사다리와 전설 화면 스킬을 정한다.
  final int rarity;

  /// 등급 사다리를 적용한 기본 공격.
  final AttackDef attack;
  final SkillDef skill;

  /// 전설 고유 능력 (전설 미만이면 null).
  final LegendDef? legend;

  /// 다음 발사까지 남은 초 (공격 속도 배율 적용 전 기준).
  double cooldown = 0;

  /// 다음 스킬까지 남은 초 (공격 속도 배율 적용 전 기준).
  double skillCooldown = 0;

  /// 다음 보호막까지 남은 초(legend.shield, 개성 v2 7.1). 0이면 첫 틱에 세운다.
  double shieldTimer = 0;

  FleetSlot view() {
    double ratio(double left, double full) => full <= 0 ? 0.0 : (left / full).clamp(0.0, 1.0);
    return FleetSlot(
      crewId: crewId,
      cooldown: ratio(cooldown, attack.intervalSec),
      skillCooldown: ratio(skillCooldown, skill.cooldownSec),
      rarity: rarity,
    );
  }
}
