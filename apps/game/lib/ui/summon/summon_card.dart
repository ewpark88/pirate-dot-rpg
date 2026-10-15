import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_fx.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 소환 연출 카드 한 장: 착지([land]) · 뒷면 기대감([hint]) · 3D 뒤집기([flip]) · NEW 도장 / 중복 ‘+카드’.
class SummonRevealCard extends ConsumerWidget {
  const SummonRevealCard({
    required this.index,
    required this.result,
    required this.tier,
    required this.hint,
    required this.land,
    required this.flip,
    required this.onTap,
    super.key,
  });

  final int index;
  final SummonResult result;
  final int tier;
  final double hint;
  final double land;
  final Animation<double> flip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final i = index;
    final r = result;
    final rarity = tables.rarities.rarities[tier];
    final crew = tables.crews.byId(r.crewId);
    final pity = tables.rarities.rarities.indexWhere((x) => x.id == tables.rarities.pityMinRarity);

    final back = KeyedSubtree(
      key: Key('summon.card.$i.back'),
      child: CardHint(
        tier: tier,
        color: rarityColor(rarity),
        t: hint,
        child: PbCardBack(rarityId: rarity.id),
      ),
    );
    final front = Stack(
      key: Key('summon.card.$i.face'),
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          key: tier >= Tier.legend ? Key('summon.card.$i.glow') : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              for (final (c, blur) in pbGlow[rarity.id] ?? const <(Color, double)>[])
                BoxShadow(color: c, blurRadius: blur * 2),
            ],
          ),
          child: PbCardFront(crew: crew, rarity: rarity, name: shortCrewName(l10n, crew)),
        ),
        if (tier >= pity) SizedBox.shrink(key: Key('summon.card.$i.highlight')),
        // 중복은 ‘+카드’(카드 1장 더), 새 선원은 NEW 도장.
        if (!r.isNew)
          Positioned(
            right: 4,
            top: 4,
            child: _SmallBadge(l10n.uiSummonDupe),
          ),
        if (r.isNew)
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            child: Center(
              child: AnimatedBuilder(
                animation: flip,
                builder: (_, _) =>
                    NewStamp(t: ((flip.value - 0.6) / 0.4).clamp(0, 1).toDouble(), label: l10n.uiSummonNew),
              ),
            ),
          ),
      ],
    );

    return Opacity(
      opacity: land.clamp(0, 1).toDouble(),
      child: Transform.translate(
        offset: Offset(0, (1 - land) * 260),
        child: Transform.scale(
          scale: 0.4 + 0.6 * land,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedBuilder(
              animation: flip,
              builder: (_, _) => FlipCard(t: (flip.value / 0.6).clamp(0, 1).toDouble(), back: back, front: front),
            ),
          ),
        ),
      ),
    );
  }
}

/// 카드 위 작은 금색 배지 (중복 ‘+카드’) — 카드가 작아도 가리지 않게.
class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: Skin.goldBottom,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white, width: 1.5),
    ),
    child: Text(text, style: Skin.text(11, color: Skin.goldInk)),
  );
}
