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
              counts: j.obj('arc').has('counts')
                  ? [for (final v in j.obj('arc').raw['counts'] as List) (v as num).toInt()]
                  : null,
              falloff: j.obj('arc').numberOr('falloff', 1),
            )
          : null,
      execute = j.has('execute')
          ? (below: j.obj('execute').number('below'), mul: j.obj('execute').number('mul'))
          : null,
      charge = j.has('charge')
          ? (
              every: j.obj('charge').integer('every'),
              mul: j.obj('charge').number('mul'),
              stunSec: j.obj('charge').numberOr('stunSec', 0),
            )
          : null,
      noMiss = j.raw['noMiss'] == true,
      noMissChance = j.numberOr('noMissChance', 0),
      pierceRamp = j.numberOr('pierceRamp', 0),
      boomerang = j.numberOr('boomerang', 0),
      bindSec = j.numberOr('bindSec', 0),
      sweep = j.has('sweep') ? (deg: j.obj('sweep').number('deg'), range: j.obj('sweep').number('range')) : null,
      bossBonus = j.numberOr('bossBonus', 0);

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
        ..['stunSec'] = n(a, 'stunSec') * scale; // counts(등급별 연쇄 수)는 등급마다 정한 값이라 배율 없이 그대로
      out['arc'] = a;
    }
    if (r['execute'] is Map) {
      final e = Map<String, dynamic>.of(r['execute'] as Map<String, dynamic>);
      e['mul'] = 1 + (n(e, 'mul') - 1) * scale;
      out['execute'] = e;
    }
    if (r['charge'] is Map) {
      final c = Map<String, dynamic>.of(r['charge'] as Map<String, dynamic>);
      c
        ..['mul'] = 1 + (n(c, 'mul') - 1) * scale
        ..['stunSec'] = n(c, 'stunSec') * scale;
      out['charge'] = c;
    }
    if (r['noMiss'] == true) out['noMissChance'] = scale;
    // 선원 정리 2안(BALANCE.md 4절): 연속 값은 × 배율, 휩쓸기는 각도만 배율(범위는 그대로).
    for (final k in ['pierceRamp', 'boomerang', 'bindSec', 'bossBonus']) {
      if (r.containsKey(k)) out[k] = n(r, k) * scale;
    }
    if (r['sweep'] is Map) {
      final sw = Map<String, dynamic>.of(r['sweep'] as Map<String, dynamic>);
      sw['deg'] = n(sw, 'deg') * scale;
      out['sweep'] = sw;
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
    'execute',
    'charge',
    'noMiss',
    'pierceRamp',
    'boomerang',
    'bindSec',
    'sweep',
    'bossBonus',
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
  /// 연쇄 번개(사용자 2026-10-17): counts가 있으면 등급 순번별 마리 수(배율 없음)이고, 마지막에 맞은 적에서 다음으로 튀며 한 번마다 × falloff.
  final ({int count, double chance, double ratio, double stunSec, List<int>? counts, double falloff})? arc;

  /// 처형(bones, 2026-10-17): 맞은 뒤 HP가 below 아래인 적에게 피해 × (mul − 1)을 더.
  final ({double below, double mul})? execute;

  /// 충전 사격(volt): every번째 발사마다 맞은 적에게 피해 × (mul − 1)을 더하고 기절 stunSec.
  final ({int every, double mul, double stunSec})? charge;

  /// 추적 깃털(polly): 빗나가지 않는다 — 탄이 빈자리에 떨어지면 가까운 적을 쫓고, 보스 회피(evade 특성)도 무시. 전설 미만은 발마다 noMissChance.
  final bool noMiss;
  final double noMissChance;

  /// 피버 서포트(개성 v2 7.3, pumpum): 출전 중이면 피버 게이지 충전 × (1 + chargeBonus), 피버 지속 + extraSec초.
  final ({double chargeBonus, double extraSec})? fever;

  /// 선원 정리 2안(BALANCE.md 4절, S1 승인) — 탄 +n 과다(8명) 정리.
  /// 관통 가속(sword): 관통 감쇠 대신 꿰뚫을 때마다 × (1 + pierceRamp).
  final double pierceRamp;

  /// 부메랑(saw): 같은 길로 돌아오며 맞은 적에게 한 번 더 — 피해 × boomerang.
  final double boomerang;

  /// 물기 속박(bara): 맞은 적이 이 초 동안 움직이지 못한다(공격은 한다). 보스는 bossControlFactor배.
  final double bindSec;

  /// 휩쓸기(lobster): 첫 대상 쪽 부채꼴 deg(도) 안, 첫 대상 거리 + range 안 적 전부.
  final ({double deg, double range})? sweep;

  /// 해적왕 강타(davy): 보스(분열 몸·촉수 포함) 피해 + bossBonus.
  final double bossBonus;
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
