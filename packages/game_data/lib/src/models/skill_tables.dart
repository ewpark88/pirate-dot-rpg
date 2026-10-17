import 'package:game_data/src/models/common.dart';
import 'package:game_data/src/models/legend_tables.dart';

/// 범위 모양 하나 (기본 공격·스킬 공통, 설계서 4.3.2·4.4). 모양별로 쓰는 필드만 채운다.
/// shape: circle, single, line, chain, random, cone, push, ship.
class AttackDef {
  AttackDef.fromJson(this.raw)
    : shape = raw.str('shape'),
      intervalSec = raw.numberOr('intervalSec', 0),
      power = raw.numberOr('power', 1),
      excludeLayers = raw.has('excludeLayers') ? raw.strs('excludeLayers').toSet() : const {},
      targets = raw.strOrNull('targets'),
      radius = raw.numberOr('radius', 0),
      width = raw.numberOr('width', 0),
      range = raw.numberOr('range', 0),
      angleDeg = raw.numberOr('angleDeg', 0),
      knockback = raw.numberOr('knockback', 0),
      stunSec = raw.numberOr('stunSec', 0),
      dotSec = raw.numberOr('dotSec', 0),
      shots = raw.intOrNull('shots') ?? 1,
      burst = raw.intOrNull('burst') ?? 1,
      projectiles = raw.intOrNull('projectiles') ?? 1,
      pierce = raw.intOrNull('pierce') ?? 1,
      chains = raw.intOrNull('chains') ?? 1,
      count = raw.intOrNull('count') ?? 1;

  final JsonReader raw;
  final String shape;

  /// 발사 간격(초). 돛 강화의 공격 속도 배율로 나눈다. 스킬은 0.
  final double intervalSec;

  /// 한 번 발사의 피해 배율 (계열 예산, 밸런스 시뮬로 조정).
  final double power;

  /// 이 공격이 맞히지 못하는 층.
  final Set<String> excludeLayers;

  /// 대상 고르기 힌트: nearest, cluster, strongest, random, front, self.
  final String? targets;
  final double radius;
  final double width;
  final double range;
  final double angleDeg;
  final double knockback;
  final double stunSec;

  /// 수중 장판 지속(초). 0이면 장판 없음.
  final double dotSec;

  /// 연사 발수 (연출).
  final int shots;

  /// 직사 사다리 연사 수 (연출).
  final int burst;

  /// 서로 다른 대상에 쏘는 발사체 수. 한 발 피해 = 기본 ÷ 발사체 수 (예산 유지).
  final int projectiles;
  final int pierce;
  final int chains;
  final int count;

  /// [over]의 키를 덮어쓴 모양(선원 개성 v2 `aim`). 없으면 그대로.
  /// 연사를 바꾸고 power를 주지 않으면 power = (등급 사다리) power × 새 간격 ÷ 계열 간격 — 연사형·한 방형이 같은 DPS(S2).
  /// `powerScale`(선택)은 그 위에 곱한다(선원별 미세 보정, balance crews).
  AttackDef overlay(JsonReader? over) {
    if (over == null) return this;
    final o = over.raw;
    var power = o.containsKey('power') ? over.number('power') : this.power;
    if (!o.containsKey('power') && o.containsKey('intervalSec') && intervalSec > 0) {
      power = power * over.number('intervalSec') / intervalSec;
    }
    power = power * over.numberOr('powerScale', 1);
    return AttackDef.fromJson(JsonReader({...raw.raw, ...o, 'power': power}, over.path));
  }

  /// 연사 간격만 × [k](power는 그대로 — 전설 이상 '공속 + 공격력 둘 다', skills.json rarityTempo, S2).
  AttackDef tempo(double k) =>
      k == 1 ? this : AttackDef.fromJson(JsonReader({...raw.raw, 'intervalSec': intervalSec * k}, raw.path));

  /// 날아가는 탄(선원 개성 v2 `projectile`): 탄속(단위/초)·예측 사격·도착 지점 맞는 반경. 없으면 즉시 맞는다.
  /// delaySec가 있으면 거리와 상관없이 그 시간 뒤 조준점에 떨어진다(낙뢰 예고, 개성 v2 7.2).
  ({double speed, bool lead, double hitRadius, double delaySec})? get projectile {
    if (!raw.has('projectile')) return null;
    final p = raw.obj('projectile');
    return (
      speed: p.numberOr('speed', 0),
      lead: p.raw['lead'] == true,
      hitRadius: p.numberOr('hitRadius', 0),
      delaySec: p.numberOr('delaySec', 0),
    );
  }

  /// 사다리([ladder]의 키 → 등급별 값)를 [rarity] 등급 순번으로 덮어쓴 모양.
  AttackDef withLadder(Map<String, List<num>> ladder, int rarity) {
    if (ladder.isEmpty) return this;
    return AttackDef.fromJson(
      JsonReader({
        ...raw.raw,
        for (final e in ladder.entries) e.key: e.value[rarity.clamp(0, e.value.length - 1)],
      }, raw.path),
    );
  }
}

/// 자동 스킬 (설계서 4.4). 모양은 [area], 피해 배율은 [multiplier].
class SkillDef {
  SkillDef.fromJson(this.raw)
    : id = raw.str('id'),
      area = AttackDef.fromJson(raw),
      cooldownSec = raw.number('cooldownSec'),
      multiplier = raw.number('multiplier'),
      fx = raw.str('fx'),
      heal = raw.numberOr('heal', 0),
      attackSpeedBuff = raw.numberOr('attackSpeedBuff', 0),
      buffSec = raw.numberOr('buffSec', 0);

  final JsonReader raw;
  final String id;
  final AttackDef area;
  final double cooldownSec;
  final double multiplier;
  final String fx;

  /// `ship` 모양: 배 최대 HP 대비 회복 비율, 공격 속도 버프와 지속.
  final double heal;
  final double attackSpeedBuff;
  final double buffSec;

  String get shape => area.shape;
  int get count => area.count;
}

/// 선장 궁극기 (설계서 4.4): 화면 전체 피해 + 계열별 추가 효과.
class UltimateDef {
  UltimateDef.fromJson(JsonReader j)
    : id = j.str('id'),
      fx = j.str('fx'),
      knockback = j.numberOr('knockback', 0),
      stunSec = j.numberOr('stunSec', 0),
      healRatio = j.numberOr('healRatio', 0);

  final String id;
  final String fx;
  final double knockback;
  final double stunSec;
  final double healRatio;
}

class FamilyDef {
  FamilyDef.fromJson(JsonReader j)
    : id = j.str('id'),
      projectile = j.strOrNull('projectile'),
      attack = AttackDef.fromJson(j.obj('attack')),
      skill = SkillDef.fromJson(j.obj('skill')),
      ultimate = UltimateDef.fromJson(j.obj('ultimate')),
      ladder = {
        if (j.has('ladder'))
          for (final e in (j.raw['ladder'] as Map<String, dynamic>).entries) e.key: (e.value as List).cast<num>(),
      },
      nameKey = j.str('nameKey');

  final String id;
  final String? projectile;
  final AttackDef attack;
  final SkillDef skill;
  final UltimateDef ultimate;

  /// 등급별 발사체 사다리 (설계서 4.3.2): 키 → [일반, 희귀, 영웅, 전설, 신화].
  final Map<String, List<num>> ladder;
  final String nameKey;

  String get ultimateId => ultimate.id;
  String get ultimateFx => ultimate.fx;

  /// [rarity] 등급(0 = 일반)의 기본 공격.
  AttackDef attackAt(int rarity) => attack.withLadder(ladder, rarity);
}

class SkillsTable {
  SkillsTable.fromJson(JsonReader j)
    : raw = j,
      families = j.objs('families').map(FamilyDef.fromJson).toList(),
      crewSkills = j.objs('crewSkills').map(SkillDef.fromJson).toList(),
      maxSameFamilyInFleet = j.integer('maxSameFamilyInFleet'),
      legendSkillScope = j.str('legendSkillScope'),
      bossControlFactor = j.number('bossControlFactor'),
      ultimateMultiplier = j.number('ultimateMultiplier'),
      critBurstDamage = j.number('critBurstDamage'),
      legends = {
        for (final e in (j.raw['legends'] as Map<String, dynamic>).entries) e.key: j.obj('legends').obj(e.key),
      },
      traitScale = j.has('traitScale')
          ? [for (final v in j.raw['traitScale'] as List) (v as num).toDouble()]
          : const [],
      rarityTempo = j.has('rarityTempo')
          ? [for (final v in j.raw['rarityTempo'] as List) (v as num).toDouble()]
          : const [];

  /// 원문(선택 키 — 예 bossBreak, 도감·브레이크 v2).
  final JsonReader raw;

  final List<FamilyDef> families;

  /// 계열 스킬 대신 선원이 고를 수 있는 스킬 (crews.json의 `skill`).
  final List<SkillDef> crewSkills;
  final int maxSameFamilyInFleet;

  /// 전설 이상 선원의 스킬 범위 (`screen` = 화면 전체).
  final String legendSkillScope;

  /// 보스가 받는 기절·밀어내기 비율 (설계서 4.10: 절반).
  final double bossControlFactor;

  /// 피버 첫 일격(궁극기 효과) 피해 = 기본 공격 피해 × 이 값.
  final double ultimateMultiplier;

  /// 전설 치명타 폭발 피해 비율.
  final double critBurstDamage;

  /// 선원 개성 v2 특징 배율(등급 순번 0~전설 전): 전설 미만도 전설 능력을 이 배율로(일반 0.4…). 비면 전설부터만.
  final List<double> traitScale;

  /// 등급 순번별 연사 간격 배율(전설 이상 빠르게, power 그대로 — S2). 비거나 짧으면 1.
  final List<double> rarityTempo;

  /// 선원 id → 전설 능력 원문 (등급에 따라 [legendFor]).
  final Map<String, JsonReader> legends;

  /// [rarity] 등급(3 = 전설, 4 = 신화)의 [crewId] 전설 능력. 전설 미만이거나 데이터가 없으면 null.
  LegendDef? legendFor(String crewId, int rarity, int legendRarity) {
    final raw = legends[crewId];
    if (raw == null) return null;
    if (rarity < legendRarity) {
      final k = rarity < traitScale.length ? traitScale[rarity] : 0.0;
      return k > 0 ? LegendDef.scaled(raw, k) : null; // 특징(trait, 개성 v2) — 배율 0이면 없음
    }
    return LegendDef.of(raw, mythic: rarity > legendRarity);
  }

  FamilyDef byId(String id) => families.firstWhere((f) => f.id == id);

  /// 계열 스킬과 선원 스킬 전체의 id.
  Set<String> get skillIds => {for (final f in families) f.skill.id, for (final s in crewSkills) s.id};

  /// [id]의 스킬 정의 (계열 스킬 또는 선원 스킬).
  SkillDef skillById(String id) => [...families.map((f) => f.skill), ...crewSkills].firstWhere((s) => s.id == id);

  List<String> validate(double skillCooldownMinSec) {
    final e = <String>[];
    for (final s in [...families.map((f) => f.skill), ...crewSkills]) {
      expect(
        e,
        that: s.cooldownSec >= skillCooldownMinSec,
        message: 'skills: ${s.id} 쿨타임 ${s.cooldownSec} < 최소 $skillCooldownMinSec',
      );
    }
    for (final l in legends.entries) {
      final bad = l.value.raw.keys.where((k) => !LegendDef.keys.contains(k));
      expect(e, that: bad.isEmpty, message: 'skills: legends.${l.key}의 모르는 키 $bad');
    }
    for (final f in families) {
      for (final l in f.ladder.entries) {
        expect(e, that: l.value.length == 5, message: 'skills: ${f.id} ladder.${l.key}는 등급 5개 값이어야 함');
      }
    }
    return e;
  }
}
