import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_trait_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

export 'package:pirate_dot/ui/crew/crew_trait_text.dart';

// 선원 개성 v2 표시 (기획 platform-crew-identity-v2 6절, 사용자 승인). 아이콘 4개(조준·연사·범위·명중) + 한 줄 특색.
// crews.json `aim` 계약(S2) 전에는 기획 2절 40명 표를 그대로 옮긴 [crewIdentities]로 보인다 — 계약이 오면 표 값으로 바꾼다.

enum AimKind { nearest, strongest, weakest, cluster, boss, random, farthest, air, ring }

enum HitKind { instant, lead, free }

/// 선원 한 명의 특색: 조준 · 연사 간격(초) · 범위 공격인가 · 명중 방식.
typedef CrewIdentity = ({AimKind aim, double interval, bool area, HitKind hit});

const Map<String, CrewIdentity> crewIdentities = {
  'octo': (aim: AimKind.cluster, interval: 1.4, area: true, hit: HitKind.lead),
  'starry': (aim: AimKind.strongest, interval: 2.2, area: true, hit: HitKind.lead),
  'crabs': (aim: AimKind.nearest, interval: 0.6, area: false, hit: HitKind.free),
  'uni': (aim: AimKind.random, interval: 0.9, area: true, hit: HitKind.free),
  'volke': (aim: AimKind.farthest, interval: 3.0, area: true, hit: HitKind.lead),
  'pang': (aim: AimKind.nearest, interval: 0.3, area: false, hit: HitKind.free),
  'hippo': (aim: AimKind.strongest, interval: 1.2, area: false, hit: HitKind.lead),
  'bones': (aim: AimKind.weakest, interval: 0.8, area: false, hit: HitKind.lead),
  'lion': (aim: AimKind.boss, interval: 1.6, area: false, hit: HitKind.lead),
  'volt': (aim: AimKind.cluster, interval: 1.0, area: false, hit: HitKind.instant),
  'sword': (aim: AimKind.nearest, interval: 1.0, area: false, hit: HitKind.instant),
  'nar': (aim: AimKind.farthest, interval: 2.4, area: false, hit: HitKind.instant),
  'walrus': (aim: AimKind.strongest, interval: 1.8, area: false, hit: HitKind.lead),
  'saw': (aim: AimKind.cluster, interval: 1.4, area: false, hit: HitKind.instant),
  'moby': (aim: AimKind.boss, interval: 3.0, area: false, hit: HitKind.lead),
  'otter': (aim: AimKind.nearest, interval: 0.5, area: false, hit: HitKind.free),
  'pingu': (aim: AimKind.random, interval: 1.0, area: false, hit: HitKind.free),
  'sheldon': (aim: AimKind.weakest, interval: 1.2, area: false, hit: HitKind.lead),
  'dolphy': (aim: AimKind.farthest, interval: 1.5, area: false, hit: HitKind.lead),
  'orca': (aim: AimKind.cluster, interval: 2.0, area: false, hit: HitKind.lead),
  'puffer': (aim: AimKind.nearest, interval: 1.6, area: true, hit: HitKind.free),
  'jelly': (aim: AimKind.cluster, interval: 2.4, area: true, hit: HitKind.lead),
  'bara': (aim: AimKind.strongest, interval: 1.2, area: false, hit: HitKind.lead),
  'moray': (aim: AimKind.boss, interval: 2.0, area: false, hit: HitKind.lead),
  'kraki': (aim: AimKind.cluster, interval: 3.0, area: true, hit: HitKind.lead),
  'polly': (aim: AimKind.random, interval: 0.4, area: false, hit: HitKind.free),
  'gull': (aim: AimKind.air, interval: 0.8, area: false, hit: HitKind.lead),
  'pelly': (aim: AimKind.strongest, interval: 1.4, area: true, hit: HitKind.lead),
  'alba': (aim: AimKind.farthest, interval: 2.0, area: false, hit: HitKind.lead),
  'manta': (aim: AimKind.cluster, interval: 2.6, area: true, hit: HitKind.lead),
  'shark': (aim: AimKind.nearest, interval: 0.6, area: false, hit: HitKind.instant),
  'crabby': (aim: AimKind.nearest, interval: 1.2, area: true, hit: HitKind.instant),
  'king': (aim: AimKind.strongest, interval: 1.5, area: true, hit: HitKind.instant),
  'lobster': (aim: AimKind.cluster, interval: 1.0, area: true, hit: HitKind.instant),
  'davy': (aim: AimKind.boss, interval: 2.2, area: true, hit: HitKind.instant),
  'turtle': (aim: AimKind.ring, interval: 1.8, area: true, hit: HitKind.instant),
  'pumpum': (aim: AimKind.ring, interval: 2.6, area: true, hit: HitKind.instant),
  'cook': (aim: AimKind.ring, interval: 3.0, area: true, hit: HitKind.instant),
  'corey': (aim: AimKind.ring, interval: 1.2, area: false, hit: HitKind.instant),
  'lamp': (aim: AimKind.ring, interval: 2.0, area: true, hit: HitKind.instant),
};

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
class CrewIdentityIcons extends StatelessWidget {
  const CrewIdentityIcons({required this.crewId, this.size = 14, this.light = false, super.key});

  final String crewId;
  final double size;

  /// 어두운 바탕(소환 결과) 위면 밝은 색.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final id = crewIdentities[crewId];
    if (id == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final ink = light ? Colors.white : Skin.ink;
    return Semantics(
      label:
          '${aimText(l10n, id.aim)} · ${l10n.uiRateSec(id.interval)} · '
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
class CrewIdentityPanel extends StatelessWidget {
  const CrewIdentityPanel({required this.crewId, super.key});

  final String crewId;

  @override
  Widget build(BuildContext context) {
    final id = crewIdentities[crewId];
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
                l10n.uiRateSec(id.interval),
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
