import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 10연 소환.
const _summonTen = 10;

/// 소환 탭: 1회·10회 버튼(젬 비용), 천장 진행 막대, 등급 확률표 (설계서 4.3, 9.3 확률 공개).
// TODO(ui): 증표 상점 — 다음 계획.
class SummonTab extends ConsumerWidget {
  const SummonTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    // 비용은 상태에 따라 달라진다 (첫 10연 무료) — 경제 summonCostFor로만 구한다.
    final (costOne, costTen, canOne, canTen, pity) = ref.watch(
      gameStateProvider.select(
        (s) => (
          summonCostFor(s, tables, 1),
          summonCostFor(s, tables, _summonTen),
          canSummon(s, tables, 1),
          canSummon(s, tables, _summonTen),
          s.pityCount,
        ),
      ),
    );
    final gems = ref.watch(gameStateProvider.select((s) => s.wallet.gems));
    final rarities = tables.rarities;
    final pityRarity = rarities.rarities.firstWhere((r) => r.id == rarities.pityMinRarity);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 보유 젬 — 캔버스 HUD에는 골드만 있어 젬은 쓰는 곳(소환 탭)에 보인다.
        Row(
          key: const Key('summon.gems'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const PixelSprite(UiSprites.gem, dots: 8, frames: 3, scale: 1),
            const SizedBox(width: 4),
            Text(gems.toString()),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (key, count, label) in [
              ('summon.one', 1, l10n.uiSummonOne),
              ('summon.ten', _summonTen, l10n.uiSummonTen),
            ]) ...[
              Expanded(
                child: TutorialSpot(
                  id: key,
                  child: _SummonButton(
                    buttonKey: Key(key),
                    label: label,
                    cost: count == 1 ? costOne : costTen,
                    onPressed: (count == 1 ? canOne : canTen) ? () => _summon(ref, count) : null,
                  ),
                ),
              ),
              if (count == 1) const SizedBox(width: 12),
            ],
          ],
        ),
        // 광고가 없으면 자리도 차지하지 않는다.
        const Center(child: FreeSummonAdButton()),
        const SizedBox(height: 12),
        Text(l10n.uiSummonPity(rarities.pityCount, tableText(l10n, pityRarity.nameKey))),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: PixelBar(value: pity / rarities.pityCount, fill: PixelPalette.accent),
            ),
            const SizedBox(width: 8),
            Text(l10n.uiSummonPityProgress(pity, rarities.pityCount)),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.uiSummonRates, style: Theme.of(context).textTheme.titleSmall),
        for (final r in rarities.rarities.where((r) => r.summonRate > 0)) _RateRow(rarity: r),
      ],
    );
  }
}

/// 소환 명령. 튜토리얼 4단계는 결과 창(SummonResultDialog)을 닫을 때 끝난다.
void _summon(WidgetRef ref, int count) => ref.read(commandSinkProvider).send(Summon(count: count));

class _SummonButton extends StatelessWidget {
  const _SummonButton({required this.buttonKey, required this.label, required this.cost, required this.onPressed});

  final Key buttonKey;
  final String label;
  final int cost;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PixelButton(
    key: buttonKey,
    primary: true,
    onPressed: onPressed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (cost == 0)
          Text(AppLocalizations.of(context).uiSummonFree, key: const Key('summon.free'))
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelSprite(UiSprites.gem, dots: 8, frames: 3, scale: 1),
              const SizedBox(width: 4),
              Text(cost.toString()),
            ],
          ),
      ],
    ),
  );
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rarity});

  final RarityDef rarity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: Key('summon.rate.${rarity.id}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox.square(dimension: 8, child: ColoredBox(color: rarityColor(rarity))),
          const SizedBox(width: 6),
          Expanded(child: Text(tableText(l10n, rarity.nameKey))),
          Text(percentText(l10n, rarity.summonRate)),
        ],
      ),
    );
  }
}
