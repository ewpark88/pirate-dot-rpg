import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_trait_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

export 'package:pirate_dot/ui/crew/crew_trait_text.dart';

// 선원 개성 v2 표시 (기획 platform-crew-identity-v2 6절, 사용자 승인). 아이콘 4개(조준·연사·범위·명중) + 한 줄 특색.
// 값은 crews.json `aim` 계약(S2 171fb70)에서 [crewIdentity]로 읽는다.

enum AimKind { nearest, strongest, weakest, cluster, boss, random, farthest, air, ring }

enum HitKind { instant, lead, free }

/// 선원 한 명의 특색: 조준 · 연사 간격(초) · 범위 공격인가 · 명중 방식.
typedef CrewIdentity = ({AimKind aim, double interval, bool area, HitKind hit});

/// 선원 특색을 표(crews.json `aim` · 계열 공격)에서 읽는다 (S2 개성 v2 계약). aim이 없으면 계열 공격 그대로.
/// - 조준: aim.targets(없으면 계열 targets — 'front'는 배 둘레).
/// - 범위: 모양(aim.shape ?? 계열 shape)이 원·부채꼴·밀어내기이거나 topRadius가 있으면.
/// - 명중: 발사체가 없으면 즉시(근접·광선), 예측(lead)이거나 속도 없는 지연 공격이면 예측, 아니면 빗나갈 수 있음.
CrewIdentity? crewIdentity(GameTables t, String crewId) {
  final def = t.crews.crews.where((c) => c.id == crewId).firstOrNull;
  if (def == null) return null;
  final attack = t.skills.byId(def.family).attack;
  final aim = def.aim;
  final targets = aim?.strOrNull('targets') ?? attack.targets;
  final shape = aim?.strOrNull('shape') ?? attack.shape;
  final area = const {'circle', 'cone', 'push'}.contains(shape) || (aim?.has('topRadius') ?? false);
  final projectile = aim != null && aim.has('projectile') ? aim.obj('projectile') : null;
  final HitKind hit;
  if (projectile == null) {
    hit = HitKind.instant;
  } else if (projectile.raw['lead'] == true || !projectile.has('speed')) {
    hit = HitKind.lead;
  } else {
    hit = HitKind.free;
  }
  return (
    aim: AimKind.values.where((a) => a.name == targets).firstOrNull ?? AimKind.ring,
    interval: aim?.numberOr('intervalSec', attack.intervalSec) ?? attack.intervalSec,
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
};

/// 아이콘 4개 한 줄 (카드 아래 작게 / 상세에 크게). [size] = 아이콘 한 칸 크기.
class CrewIdentityIcons extends ConsumerWidget {
  const CrewIdentityIcons({required this.crewId, this.size = 14, this.light = false, super.key});

  final String crewId;
  final double size;

  /// 어두운 바탕(소환 결과) 위면 밝은 색.
  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = crewIdentity(ref.watch(tablesProvider), crewId);
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
          _RateBars(bars: rateBars(id.interval), size: size, color: ink),
          SizedBox(width: size * 0.3),
          Icon(
            id.area ? Icons.blur_circular_rounded : Icons.fiber_manual_record_rounded,
            size: id.area ? size : size * 0.6,
            color: ink,
          ),
          SizedBox(width: size * 0.3),
          CustomPaint(
            size: Size.square(size),
            painter: _ArrowPainter(curved: id.hit == HitKind.free, color: ink),
          ),
        ],
      ),
    );
  }
}

class _RateBars extends StatelessWidget {
  const _RateBars({required this.bars, required this.size, required this.color});

  final int bars;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(width: size * 0.08),
          Container(
            width: size * 0.18,
            height: size * (0.35 + 0.13 * i),
            decoration: BoxDecoration(
              color: i < bars ? color : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 명중: 곧은 화살(즉시·예측 = 거의 맞음) / 휜 화살(빗나갈 수 있음).
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.curved, required this.color});

  final bool curved;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(w * 0.1, w * 0.6);
    if (curved) {
      path.quadraticBezierTo(w * 0.45, w * 0.05, w * 0.85, w * 0.45);
    } else {
      path.lineTo(w * 0.85, w * 0.6);
    }
    canvas.drawPath(path, p);
    final tip = curved ? Offset(w * 0.85, w * 0.45) : Offset(w * 0.85, w * 0.6);
    final back = curved ? const Offset(-0.32, -0.05) : const Offset(-0.25, -0.2);
    final back2 = curved ? const Offset(-0.12, -0.32) : const Offset(-0.25, 0.2);
    canvas
      ..drawLine(tip, tip + back * w, p)
      ..drawLine(tip, tip + back2 * w, p);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.curved != curved || old.color != color;
}

/// 상세의 특색 판: 아이콘마다 이름 + 한 줄 특색.
class CrewIdentityPanel extends ConsumerWidget {
  const CrewIdentityPanel({required this.crewId, super.key});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = crewIdentity(ref.watch(tablesProvider), crewId);
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
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item(Icon(aimIcon(id.aim), size: 20, color: Skin.ink), l10n.uiIdAim, aimText(l10n, id.aim)),
              item(
                _RateBars(bars: rateBars(id.interval), size: 18, color: Skin.ink),
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
                  size: const Size.square(20),
                  painter: _ArrowPainter(curved: id.hit == HitKind.free, color: Skin.ink),
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
