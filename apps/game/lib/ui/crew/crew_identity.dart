import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_identity_paint.dart';
import 'package:pirate_dot/ui/crew/crew_trait_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

export 'package:pirate_dot/ui/crew/crew_trait_text.dart';

// 선원 개성 v2 표시 (기획 platform-crew-identity-v2 6절, 사용자 승인). 아이콘 4개(조준·연사·범위·명중) + 한 줄 특색.
// 값은 crews.json `aim` 계약(S2 171fb70)에서 [crewIdentity]로 읽는다.

enum AimKind { nearest, strongest, weakest, cluster, boss, random, farthest, air, ring }

enum HitKind { instant, lead, free, homing }

/// 선원 한 명의 특색: 조준 · 연사 간격(초) · 범위 공격인가 · 명중 방식.
/// range = 사거리 단계 0 짧음 · 1 보통 · 2 김 (사용자 지시 '캐릭터마다 사정거리 차등', S2 aim reach).
typedef CrewIdentity = ({AimKind aim, double interval, bool area, HitKind hit, int range});

/// 사거리(reach: 배 둘레 → 적 가장자리) → 단계. 짧음 ≤ 90 · 보통 91~140 · 김 ≥ 141 (S2 기준).
int rangeLevel(double reach) => reach <= 90 ? 0 : (reach <= 140 ? 1 : 2);

/// 선원 특색을 표(crews.json `aim` · 계열 공격)에서 읽는다 (S2 개성 v2 계약). aim이 없으면 계열 공격 그대로.
/// - 조준: aim.targets(없으면 계열 targets — 'front'는 배 둘레).
/// - 범위: 모양(aim.shape ?? 계열 shape)이 원·부채꼴·밀어내기이거나 topRadius가 있으면.
/// - 명중: 발사체가 없으면 즉시(근접·광선), 예측(lead)이거나 속도 없는 지연 공격이면 예측, 아니면 빗나갈 수 있음.
/// 범위 공격으로 보는 모양: 원 · 부채꼴 · 밀어내기 · 원형 탄막(ring) · 집속탄(cluster) — 계열 v3(S5). 레이저는 줄 관통이라 아님.
const areaShapes = {'circle', 'cone', 'push', 'ring', 'cluster'};

/// [rarity] = 등급 번호(0 일반 … 4 신화) — 연사는 경제 crewAttack(등급 템포·등급별 aim 반영, S2).
CrewIdentity? crewIdentity(GameTables t, String crewId, {int rarity = 0}) {
  final def = t.crews.crews.where((c) => c.id == crewId).firstOrNull;
  if (def == null) return null;
  final attack = t.skills.byId(def.family).attack;
  final aim = def.aim;
  final targets = aim?.strOrNull('targets') ?? attack.targets;
  final shape = aim?.strOrNull('shape') ?? attack.shape;
  final area = areaShapes.contains(shape) || (aim?.has('topRadius') ?? false);
  final projectile = aim != null && aim.has('projectile') ? aim.obj('projectile') : null;
  final HitKind hit;
  // 추적 깃털(polly, 전설 noMiss 2026-10-17): 빈자리에 떨어져도 가까운 적을 쫓는다 — 빗나가지 않음.
  final legendIdx = t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  if (t.skills.legendFor(crewId, legendIdx, legendIdx)?.noMiss ?? false) {
    hit = HitKind.homing;
  } else if (projectile == null) {
    hit = HitKind.instant;
  } else if (projectile.raw['lead'] == true || !projectile.has('speed')) {
    hit = HitKind.lead;
  } else {
    hit = HitKind.free;
  }
  return (
    aim: AimKind.values.where((a) => a.name == targets).firstOrNull ?? AimKind.ring,
    interval: crewAttack(t, crewId, rarity).intervalSec,
    range: rangeLevel(crewAttack(t, crewId, rarity).raw.numberOr('reach', 0)),
    area: area,
    hit: hit,
  );
}

/// 연사 막대 칸 수 1~5 (짧은 간격일수록 많이).
int rateBars(double interval) => switch (interval) {
  <= 0.5 => 5,
  <= 0.9 => 4,
  <= 1.4 => 3,
  <= 2.2 => 2,
  _ => 1,
};

IconData aimIcon(AimKind a) => switch (a) {
  AimKind.nearest => Icons.gps_fixed_rounded,
  AimKind.strongest => Icons.fitness_center_rounded,
  AimKind.weakest => Icons.heart_broken_rounded,
  AimKind.cluster => Icons.bubble_chart_rounded,
  AimKind.boss => Icons.military_tech_rounded,
  AimKind.random => Icons.casino_rounded,
  AimKind.farthest => Icons.open_in_full_rounded,
  AimKind.air => Icons.flight_rounded,
  AimKind.ring => Icons.radio_button_checked_rounded,
};

String aimText(AppLocalizations l, AimKind a) => switch (a) {
  AimKind.nearest => l.uiAimNearest,
  AimKind.strongest => l.uiAimStrongest,
  AimKind.weakest => l.uiAimWeakest,
  AimKind.cluster => l.uiAimCluster,
  AimKind.boss => l.uiAimBoss,
  AimKind.random => l.uiAimRandom,
  AimKind.farthest => l.uiAimFarthest,
  AimKind.air => l.uiAimAir,
  AimKind.ring => l.uiAimRing,
};

String hitText(AppLocalizations l, HitKind h) => switch (h) {
  HitKind.instant => l.uiHitInstant,
  HitKind.lead => l.uiHitLead,
  HitKind.free => l.uiHitFree,
  HitKind.homing => l.uiHitHoming,
};

/// 아이콘 4개 한 줄 (카드 아래 작게 / 상세에 크게). [size] = 아이콘 한 칸 크기.
class CrewIdentityIcons extends ConsumerWidget {
  const CrewIdentityIcons({required this.crewId, this.size = 14, this.light = false, this.rarity = 0, super.key});

  final String crewId;

  /// 등급 번호 (연사 간격이 등급 템포를 따른다).
  final int rarity;
  final double size;

  /// 어두운 바탕(소환 결과) 위면 밝은 색.
  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = crewIdentity(ref.watch(tablesProvider), crewId, rarity: rarity);
    if (id == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final ink = light ? Colors.white : Skin.ink;
    return Semantics(
      label:
          '${aimText(l10n, id.aim)} · ${l10n.uiRateSec(shortDecimal(id.interval))} · '
          '${id.area ? l10n.uiAreaWide : l10n.uiAreaSingle} · ${hitText(l10n, id.hit)}',
      excludeSemantics: true,
      child: Row(
        key: Key('crew.identity.$crewId'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(aimIcon(id.aim), size: size, color: ink),
          SizedBox(width: size * 0.3),
          IdRateBars(bars: rateBars(id.interval), size: size, color: ink),
          SizedBox(width: size * 0.3),
          CustomPaint(
            size: Size(size * 1.2, size),
            painter: IdRangePainter(level: id.range, color: ink),
          ),
          SizedBox(width: size * 0.3),
          Icon(
            id.area ? Icons.blur_circular_rounded : Icons.fiber_manual_record_rounded,
            size: id.area ? size : size * 0.6,
            color: ink,
          ),
          SizedBox(width: size * 0.3),
          CustomPaint(
            size: Size.square(size),
            painter: IdArrowPainter(curved: id.hit == HitKind.free, color: ink),
          ),
        ],
      ),
    );
  }
}

String rangeText(AppLocalizations l, int level) => switch (level) {
  0 => l.uiRangeShort,
  1 => l.uiRangeMid,
  _ => l.uiRangeLong,
};

/// 상세의 특색 판: 아이콘마다 이름 + 한 줄 특색.
class CrewIdentityPanel extends ConsumerWidget {
  const CrewIdentityPanel({required this.crewId, this.rarity = 0, super.key});

  final String crewId;

  /// 등급 번호 (연사 · 신화 작은 폭발).
  final int rarity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = crewIdentity(ref.watch(tablesProvider), crewId, rarity: rarity);
    if (id == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    Widget item(Widget icon, String label, String value) => Expanded(
      child: Column(
        children: [
          SizedBox(height: 22, child: Center(child: icon)),
          const SizedBox(height: 2),
          Text(label, style: Skin.text(11, color: Skin.sub)),
          Text(value, textAlign: TextAlign.center, maxLines: 2, style: Skin.text(12)),
        ],
      ),
    );
    return Container(
      key: Key('crew.identity.panel.$crewId'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Skin.cardEdge, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            crewTraitLine(l10n, crewId),
            key: const Key('crew.identity.line'),
            style: Skin.text(15, color: Skin.primaryEdge),
          ),
          // 신화 단일형: 맞은 자리 작은 폭발(경제 aim.mythic splashRadius, S2).
          if (crewAttack(ref.watch(tablesProvider), crewId, rarity).raw.numberOr('splashRadius', 0) > 0)
            Text(
              l10n.uiIdSplash,
              key: const Key('crew.identity.splash'),
              style: Skin.text(13, color: Skin.goldInk),
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item(Icon(aimIcon(id.aim), size: 20, color: Skin.ink), l10n.uiIdAim, aimText(l10n, id.aim)),
              item(
                IdRateBars(bars: rateBars(id.interval), size: 18, color: Skin.ink),
                l10n.uiIdRate,
                l10n.uiRateSec(shortDecimal(id.interval)),
              ),
              item(
                Icon(
                  id.area ? Icons.blur_circular_rounded : Icons.fiber_manual_record_rounded,
                  size: id.area ? 20 : 12,
                  color: Skin.ink,
                ),
                l10n.uiIdArea,
                id.area ? l10n.uiAreaWide : l10n.uiAreaSingle,
              ),
              item(
                CustomPaint(
                  size: const Size(24, 20),
                  painter: IdRangePainter(level: id.range, color: Skin.ink),
                ),
                l10n.uiIdRange,
                rangeText(l10n, id.range),
              ),
              item(
                CustomPaint(
                  size: const Size.square(20),
                  painter: IdArrowPainter(curved: id.hit == HitKind.free, color: Skin.ink),
                ),
                l10n.uiIdHit,
                hitText(l10n, id.hit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
