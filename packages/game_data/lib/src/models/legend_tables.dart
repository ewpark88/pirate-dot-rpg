import 'package:game_data/src/models/common.dart';

/// 선원별 전설 고유 능력 (docs/specs/battle-m3-legend.md). 신화면 [LegendDef.of]가 `mythic` 값으로 덮는다.
class LegendDef {
  LegendDef.fromJson(JsonReader j)
    : extraProjectiles = j.intOrNull('extraProjectiles') ?? 0,
      extraChains = j.intOrNull('extraChains') ?? 0,
      noFalloff = j.raw['noFalloff'] == true,
      critBurst = j.numberOr('critBurst', 0),
      onHit = j.has('onHit') ? OnHitDef.fromJson(j.obj('onHit')) : const OnHitDef(),
      zone = j.has('zone') ? LegendZoneDef.fromJson(j.obj('zone')) : null;

  /// [raw]의 기본 값에 [mythic]이면 `mythic` 키들을 덮어쓴 능력.
  factory LegendDef.of(JsonReader raw, {required bool mythic}) => LegendDef.fromJson(
    mythic && raw.has('mythic')
        ? JsonReader({...raw.raw, ...(raw.raw['mythic'] as Map<String, dynamic>)}, raw.path)
        : raw,
  );

  static const keys = {'extraProjectiles', 'extraChains', 'noFalloff', 'critBurst', 'onHit', 'zone', 'mythic'};

  final int extraProjectiles;
  final int extraChains;
  final bool noFalloff;

  /// 치명타일 때 맞은 자리 원형 범위(반경, 0 = 없음).
  final double critBurst;
  final OnHitDef onHit;
  final LegendZoneDef? zone;
}

/// 맞은 적에게 거는 효과.
class OnHitDef {
  const OnHitDef({
    this.slow = 0,
    this.slowSec = 0,
    this.burnSec = 0,
    this.burnRatio = 0,
    this.stunSec = 0,
    this.vulnerable = 0,
    this.vulnerableSec = 0,
    this.pull = 0,
  });

  OnHitDef.fromJson(JsonReader j)
    : slow = j.numberOr('slow', 0),
      slowSec = j.numberOr('slowSec', 0),
      burnSec = j.numberOr('burnSec', 0),
      burnRatio = j.numberOr('burnRatio', 0),
      stunSec = j.numberOr('stunSec', 0),
      vulnerable = j.numberOr('vulnerable', 0),
      vulnerableSec = j.numberOr('vulnerableSec', 0),
      pull = j.numberOr('pull', 0);

  final double slow;
  final double slowSec;
  final double burnSec;

  /// 화상 총 피해 = 그 공격 피해 × burnRatio, burnSec 동안 나눠.
  final double burnRatio;
  final double stunSec;

  /// 받는 피해 +비율 (같은 종류는 큰 것 하나).
  final double vulnerable;
  final double vulnerableSec;

  /// 조준점 쪽으로 끌어당김(px). 음수면 밀어냄.
  final double pull;
}

/// 전설 장판: 피해 없이 감속·주기 기절.
class LegendZoneDef {
  LegendZoneDef.fromJson(JsonReader j)
    : radius = j.number('radius'),
      sec = j.number('sec'),
      slow = j.numberOr('slow', 0),
      stunEverySec = j.numberOr('stunEverySec', 0),
      stunSec = j.numberOr('stunSec', defaultZoneStunSec);

  final double radius;
  final double sec;
  final double slow;
  final double stunEverySec;

  /// 주기 기절 1회의 길이 (설계서 4.10 젤리: 0.2초).
  final double stunSec;

  static const defaultZoneStunSec = 0.2;
}
