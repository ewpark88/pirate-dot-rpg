import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/summon/summon_fx.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 전설·신화 단독 컷인: 빛 회전 배경(card_legend_rays) 위로 큰 카드가 확대되며 등장, 이름·한 줄. 탭하면 [onDone].
/// 빛 회전은 `_spin` 동안만 돈다(끝이 있음). 신화는 오로라를 겹친다.
class SummonCutIn extends StatefulWidget {
  const SummonCutIn({required this.crew, required this.rarity, required this.tier, required this.onDone, super.key});

  final CrewDef crew;
  final RarityDef rarity;
  final int tier;
  final VoidCallback onDone;

  @override
  State<SummonCutIn> createState() => _SummonCutInState();
}

class _SummonCutInState extends State<SummonCutIn> with SingleTickerProviderStateMixin {
  static const _spin = Duration(milliseconds: 3200);

  late final AnimationController _t = AnimationController(vsync: this, duration: _spin)..forward();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mythic = widget.tier >= Tier.mythic;
    return GestureDetector(
      key: const Key('summon.cutin'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDone,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final t = _t.value;
          final zoom = Curves.easeOutBack.transform((t / 0.25).clamp(0, 1).toDouble());
          return ColoredBox(
            color: Skin.night.withValues(alpha: 0.92),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 빛 회전 배경.
                Transform.rotate(
                  angle: t * math.pi * 0.6,
                  // 그림 자체 투명도(Opacity 층은 560dp 텍스처를 매 프레임 만든다 — S3·S5 그래픽 메모리 점검 2026-10-18).
                  child: SizedBox.square(
                    dimension: 560,
                    child: Image.asset(
                      pbLegendRays,
                      fit: BoxFit.contain,
                      opacity: const AlwaysStoppedAnimation(0.85),
                    ),
                  ),
                ),
                if (mythic) Positioned.fill(child: AuroraSweep(t: t)),
                Positioned.fill(
                  child: SparkBurst(t: (t / 0.6).clamp(0, 1).toDouble(), rainbow: mythic),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.3 + 0.7 * zoom,
                      child: SizedBox(
                        width: 240,
                        child: PbCardFront(
                          crew: widget.crew,
                          rarity: widget.rarity,
                          name: shortCrewName(l10n, widget.crew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: ((t - 0.2) / 0.2).clamp(0, 1).toDouble(),
                      child: Column(
                        children: [
                          Text(
                            mythic ? l10n.uiSummonCutinMythic : l10n.uiSummonCutinLegend,
                            textAlign: TextAlign.center,
                            style: Skin.text(22, color: rarityColor(widget.rarity)),
                          ),
                          const SizedBox(height: 6),
                          Text(l10n.uiSummonTapContinue, style: Skin.text(15, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
