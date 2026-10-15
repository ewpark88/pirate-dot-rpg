import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/big_num_text.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 강화 버튼 최소 폭.
const _buttonMinWidth = 100.0;

/// 배 탭: 부위 5줄 (이름·레벨·현재 효과·강화 비용 버튼). 효과·비용은 경제 함수로만 구한다 (설계서 4.2).
// TODO(ui): 꾹 눌러 연속 강화, 자동 강화 토글, 배 등급 진행 막대 — 다음 계획.
class ShipTab extends ConsumerWidget {
  const ShipTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [for (final def in tables.shipParts.parts) _PartRow(def: def)],
    );
  }
}

class _PartRow extends ConsumerWidget {
  const _PartRow({required this.def});

  final ShipPartDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 골드는 틱마다 바뀌므로 "살 수 있나"만 구독한다.
    final (level, affordable) = ref.watch(
      gameStateProvider.select((s) {
        final lv = s.ship.parts[def.id] ?? 0;
        return (lv, s.wallet.gold >= partCost(def, lv));
      }),
    );
    final max = def.maxLevel;
    final maxed = max != null && level >= max;
    final cost = partCost(def, level);

    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: PixelPalette.textDim);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      // 안쪽 여백 = 프레임 3칸 + 2칸.
      child: PixelFrame(
        padding: 5,
        child: Row(
          children: [
            // 부위 아이콘 (아트 레인 16px × 2).
            PixelSprite(UiSprites.part(def.id), dots: 16, key: Key('ship.icon.${def.id}')),
            const SizedBox(width: 8),
            // 이름과 레벨은 한 덩어리.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tableText(l10n, def.nameKey), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(max == null ? l10n.uiLevel(level) : l10n.uiLevelMax(level, max), style: small),
                ],
              ),
            ),
            Text(
              partEffectText(l10n, def, partEffect(def, level)),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: PixelPalette.accent),
            ),
            const SizedBox(width: 8),
            // 비용 글자 길이와 상관없이 버튼 폭을 맞춘다(줄마다 오른쪽 끝 정렬).
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _buttonMinWidth),
              child: TutorialSpot(
                id: 'ship.upgrade.${def.id}',
                child: PixelButton(
                  key: Key('ship.upgrade.${def.id}'),
                  primary: true,
                  onPressed: maxed || !affordable
                      ? null
                      : () => ref.read(commandSinkProvider).send(UpgradePart(def.id)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!maxed) ...[
                        Opacity(
                          opacity: affordable ? 1 : 0.5,
                          child: const PixelSprite(UiSprites.coin, dots: 16, scale: 1),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (maxed) Text(l10n.uiShipMaxed) else BigNumText(cost),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
