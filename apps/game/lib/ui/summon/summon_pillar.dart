import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/summon/summon_fx.dart';

// 소환 연출 v3 (S1 목록 3): 카드가 뒤집힐 때 등급별 빛기둥이 뒤에서 솟는다 — 희귀 파랑 · 영웅 보라 · 전설 금 · 신화 무지개.
// 신화만 카드 뒤에서 무지개 빛살(card_legend_rays)이 한 바퀴 돈다. 모두 뒤집기 진행([t])으로만 움직인다(끝없는 애니메이션 없음).

/// 등급별 빛기둥 색 (아래 → 위). 일반은 없음.
List<Color>? pillarColors(int tier) => switch (tier) {
  Tier.rare => const [Color(0xFF4FA3FF), Color(0x004FA3FF)],
  Tier.hero => const [Color(0xFFB36BFF), Color(0x00B36BFF)],
  Tier.legend => const [Color(0xFFFFD84A), Color(0xFFFFF4C2), Color(0x00FFD84A)],
  Tier.mythic => const [Color(0xFFFF6FD8), Color(0xFF7CF2FF), Color(0xFFFFE15A), Color(0x00FFFFFF)],
  _ => null,
};

/// 카드 뒤 빛기둥 + (신화) 빛살. [t] = 뒤집기 진행 0~1 — 앞면이 보이기 시작하는 0.3부터 솟는다.
class SummonPillar extends StatelessWidget {
  const SummonPillar({required this.tier, required this.t, required this.child, super.key});

  final int tier;
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = pillarColors(tier);
    if (colors == null || t <= 0.3) return child;
    // 0.3 → 0.8 동안 솟고(아래에서 위로), 그다음 은은하게 남는다.
    final rise = Curves.easeOutCubic.transform(((t - 0.3) / 0.5).clamp(0, 1).toDouble());
    final strong = tier >= Tier.legend;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (tier >= Tier.mythic)
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Transform.rotate(
                  key: const Key('summon.rays'),
                  angle: rise * math.pi,
                  child: Opacity(
                    opacity: 0.85 * rise,
                    child: Image.asset(pbLegendRays, width: 260, height: 260, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: strong ? -6 : 6,
          right: strong ? -6 : 6,
          bottom: 0,
          top: -90 * rise,
          child: IgnorePointer(
            child: Opacity(
              opacity: (strong ? 0.95 : 0.7) * rise,
              child: DecoratedBox(
                key: Key('summon.pillar.$tier'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: colors),
                  boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.6), blurRadius: strong ? 28 : 16)],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
