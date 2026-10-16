import 'package:game_data/src/models/common.dart';

/// 선원별 전설 고유 능력 (docs/specs/battle-m3-legend.md). 신화면 [LegendDef.of]가 `mythic` 값으로 덮는다.
class LegendDef {
  LegendDef.fromJson(JsonReader j)
    : extraProjectiles = j.intOrNull('extraProjectiles') ?? 0,
      extraChains = j.intOrNull('extraChains') ?? 0,
      noFalloff = j.raw['noFalloff'] == true,
      critBurst = j.numberOr('critBurst', 0),
      powerScale = j.numberOr('powerScale', 1),
      onHit = j.has('onHit') ? OnHitDef.fromJson(j.obj('onHit')) : const OnHitDef(),
      zone = j.has('zone') ? LegendZoneDef.fromJson(j.obj('zone')) : null,
      extraProjectilesChance = j.numberOr('extraProjectilesChance', 0),
      extraChainsChance = j.numberOr('extraChainsChance', 0),
      noFalloffChance = j.numberOr('noFalloffChance', 0),
      shield = j.has('shield')
          ? (
              everySec: j.obj('shield').number('everySec'),
              durationSec: j.obj('shield').number('durationSec'),
              hpRatio: j.obj('shield').number('hpRatio'),
            )
          : null,
      fever = j.has('fever')
          ? (chargeBonus: j.obj('fever').numberOr('chargeBonus', 0), extraSec: j.obj('fever').numberOr('extraSec', 0))
          : null,
      arc = j.has('arc')
          ? (
              count: j.obj('arc').integer('count'),
              chance: j.obj('arc').numberOr('chance', 0),
              ratio: j.obj('arc').number('ratio'),
              stunSec: j.obj('arc').numberOr('stunSec', 0),
            )
          : null;

  /// [raw]의 기본 값에 [mythic]이면 `mythic` 키들을 덮어쓴 능력.
  factory LegendDef.of(JsonReader raw, {required bool mythic}) => LegendDef.fromJson(
    mythic && raw.has('mythic')
        ? JsonReader({...raw.raw, ...(raw.raw['mythic'] as Map<String, dynamic>)}, raw.path)
        : raw,
  );

  /// 선원 개성 v2 특징(trait): 전설 미만 등급은 전설 능력을 [scale]배로 — 연속 값은 × 배율, 개수형(발사체·연쇄·감쇠 없음)은
  /// 정수 몫 + 남은 몫을 '발마다 확률'로, powerScale은 1(전설부터만), mythic 없음.
  factory LegendDef.scaled(JsonReader raw, double scale) {
    double n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toDouble() ?? 0;
    final r = raw.raw;
    final out = <String, dynamic>{};
    for (final k in ['extraProjectiles', 'extraChains']) {
      final v = n(r, k) * scale;
      if (v <= 0) continue;
      out[k] = v.floor();
      out['${k}Chance'] = v - v.floor();
    }
    if (r['noFalloff'] == true) out['noFalloffChance'] = scale;
    if (r.containsKey('critBurst')) out['critBurst'] = n(r, 'critBurst') * scale;
    if (r['onHit'] is Map) {
      final o = Map<String, dynamic>.of(r['onHit'] as Map<String, dynamic>);
      for (final k in ['slow', 'burnRatio', 'stunSec', 'vulnerable', 'pull']) {
        if (o.containsKey(k)) o[k] = n(o, k) * scale;
      }
      out['onHit'] = o;
    }
    if (r['shield'] is Map) {
      final sh = Map<String, dynamic>.of(r['shield'] as Map<String, dynamic>);
      sh['hpRatio'] = n(sh, 'hpRatio') * scale;
      out['shield'] = sh;
    }
    if (r['fever'] is Map) {
      final fv = Map<String, dynamic>.of(r['fever'] as Map<String, dynamic>);
      for (final k in ['chargeBonus', 'extraSec']) {
        if (fv.containsKey(k)) fv[k] = n(fv, k) * scale;
      }
      out['fever'] = fv;
    }
    if (r['arc'] is Map) {
      final a = Map<String, dynamic>.of(r['arc'] as Map<String, dynamic>);
      final c = n(a, 'count') * scale;
      a
        ..['count'] = c.floor()
        ..['chance'] = c - c.floor()
        ..['stunSec'] = n(a, 'stunSec') * scale;
      out['arc'] = a;
    }
    if (r['zone'] is Map) {
      final z = Map<String, dynamic>.of(r['zone'] as Map<String, dynamic>);
      if (z.containsKey('slow')) z['slow'] = n(z, 'slow') * scale;
      z['stunSec'] = ((z['stunSec'] as num?)?.toDouble() ?? LegendZoneDef.defaultZoneStunSec) * scale;
      out['zone'] = z;
    }
    return LegendDef.fromJson(JsonReader(out, raw.path));
  }

  static const keys = {
    'extraProjectiles',
    'extraChains',
    'noFalloff',
    'critBurst',
    'powerScale',
    'onHit',
    'zone',
    'mythic',
    'shield',
    'arc',
    'fever',
  };

  final int extraProjectiles;
  final int extraChains;
  final bool noFalloff;

  /// 치명타일 때 맞은 자리 원형 범위(반경, 0 = 없음).
  final double critBurst;

  /// 이 선원의 피해 배율 (balance crews로 4.8 예산 ±10%에 맞춘 값, 기본 1).
  final double powerScale;
  final OnHitDef onHit;
  final LegendZoneDef? zone;

  /// 특징(전설 미만): 발마다 이 확률로 발사체 +1 · 연쇄 +1 · 감쇠 없음(엔진이 결정론 난수로 굴린다). 전설부터 0.
  final double extraProjectilesChance;
  final double extraChainsChance;
  final double noFalloffChance;

  /// 보호막(개성 v2 7.1, turtle): everySec마다 배에 흡수막 = 배 최대 HP × hpRatio, durationSec 동안. 특징 배율은 hpRatio에.
  final ({double everySec, double durationSec, double hpRatio})? shield;

  /// 번개 연쇄(개성 v2 7.2, pelly): 떨어진 자리에서 가까운 적 count(+chance 확률로 1)마리에게 피해 × ratio, 기절 stunSec.
  final ({int count, double chance, double ratio, double stunSec})? arc;

  /// 피버 서포트(개성 v2 7.3, pumpum): 출전 중이면 피버 게이지 충전 × (1 + chargeBonus), 피버 지속 + extraSec초.
  final ({double chargeBonus, double extraSec})? fever;
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
