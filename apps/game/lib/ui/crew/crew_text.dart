import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

// 선원 상세 문구: 공격 모양·스킬·전설 능력. 값은 skills.json에서 읽고 문구만 여기서 고른다.
// 주의: 생성된 l10n 함수의 인자는 알파벳순이다 (예: uiSkillRallyDesc(buff, heal, sec)).

/// 공격 모양 (`attack.shape` / `skill.shape`) → 한 줄 설명.
String shapeText(AppLocalizations l10n, String shape) => switch (shape) {
  'circle' => l10n.uiShapeCircle,
  'single' => l10n.uiShapeSingle,
  'line' => l10n.uiShapeLine,
  'chain' => l10n.uiShapeChain,
  'random' => l10n.uiShapeRandom,
  'cone' => l10n.uiShapeCone,
  'push' => l10n.uiShapePush,
  _ => l10n.uiShapeShip,
};

/// 스킬 id → 이름.
String skillName(AppLocalizations l10n, String id) => switch (id) {
  'lob_rain' => l10n.uiSkillLobRain,
  'direct_snipe' => l10n.uiSkillDirectSnipe,
  'pierce_triple' => l10n.uiSkillPierceTriple,
  'skip_splash' => l10n.uiSkillSkipSplash,
  'underwater_minefield' => l10n.uiSkillUnderwaterMinefield,
  'air_storm' => l10n.uiSkillAirStorm,
  'assault_ram' => l10n.uiSkillAssaultRam,
  'shock_wave' => l10n.uiSkillShockWave,
  'support_rally' => l10n.uiSkillSupportRally,
  _ => throw ArgumentError.value(id, 'id', 'no skill name'),
};

/// 스킬 한 줄 설명: 지원 스킬은 회복·공속, 그 밖에는 횟수·쿨타임.
String skillDesc(AppLocalizations l10n, SkillDef s) {
  if (s.heal > 0 || s.attackSpeedBuff > 0) {
    return l10n.uiSkillRallyDesc(
      percentText(l10n, s.attackSpeedBuff),
      percentText(l10n, s.heal),
      shortDecimal(s.buffSec),
    );
  }
  return l10n.uiSkillStats(s.area.count, shortDecimal(s.cooldownSec));
}

/// 전설 능력 → 줄 목록 (있는 것만).
List<String> legendLines(AppLocalizations l10n, LegendDef d) {
  final hit = d.onHit;
  final zone = d.zone;
  return [
    if (d.extraProjectiles > 0) l10n.uiLegendExtraProjectiles(d.extraProjectiles),
    // 특징(전설 미만, 개성 v2): 개수형 남은 몫은 발마다 확률.
    if (d.extraProjectilesChance > 0) l10n.uiLegendProjectileChance(percentText(l10n, d.extraProjectilesChance)),
    if (d.extraChains > 0) l10n.uiLegendExtraChains(d.extraChains),
    if (d.extraChainsChance > 0) l10n.uiLegendChainChance(percentText(l10n, d.extraChainsChance)),
    if (d.noFalloff) l10n.uiLegendNoFalloff,
    if (d.noFalloffChance > 0) l10n.uiLegendNoFalloffChance(percentText(l10n, d.noFalloffChance)),
    if (d.critBurst > 0) l10n.uiLegendCritBurst,
    if (hit.burnSec > 0) l10n.uiLegendBurn(percentText(l10n, hit.burnRatio), shortDecimal(hit.burnSec)),
    if (hit.vulnerable > 0) l10n.uiLegendVulnerable(percentText(l10n, hit.vulnerable), shortDecimal(hit.vulnerableSec)),
    if (hit.stunSec > 0) l10n.uiLegendStun(shortDecimal(hit.stunSec)),
    if (hit.slow > 0) l10n.uiLegendSlow(percentText(l10n, hit.slow), shortDecimal(hit.slowSec)),
    if (hit.pull > 0) l10n.uiLegendPull,
    if (hit.pull < 0) l10n.uiLegendPush,
    if (zone != null && zone.slow > 0) l10n.uiLegendZoneSlow(percentText(l10n, zone.slow), shortDecimal(zone.sec)),
    if (zone != null && zone.stunEverySec > 0)
      l10n.uiLegendZoneStun(shortDecimal(zone.stunEverySec), shortDecimal(zone.sec)),
    // 개성 v2 3단계: 보호막(turtle) · 낙뢰 연쇄(pelly) · 피버 서포트(pumpum).
    if (d.shield case final sh?)
      l10n.uiLegendShield(shortDecimal(sh.everySec), percentText(l10n, sh.hpRatio), shortDecimal(sh.durationSec)),
    if (d.arc case final a? when a.count > 0) l10n.uiLegendArc(a.count),
    if (d.arc case final a? when a.chance > 0) l10n.uiLegendArcChance(percentText(l10n, a.chance)),
    if (d.fever case final f?) l10n.uiLegendFever(percentText(l10n, f.chargeBonus), shortDecimal(f.extraSec)),
  ];
}
