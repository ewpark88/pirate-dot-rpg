import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

// 사용자 직접 지시 2026-10-16: 보물상자의 '젬×30·골드' 말풍선이 크고 캐릭터·전투를 가린다 → 말풍선 삭제.
// 2026-10-17: 왼쪽 알약도 없앤다 — 상자를 누르면 작은 선택 창(그냥 받기 / 광고 ×n 골드 / 광고 젬)만.

/// 떠 있는 보물상자가 있고 광고 제안이 준비됐나 (알약을 띄울지).
final chestOfferProvider = Provider<bool>((ref) {
  final chest = ref.watch(gameStateProvider.select((s) => s.battle?.chest != null));
  return chest && ref.watch(adOfferProvider(AdPlacement.chest));
});

/// 상자 그림(아트 fx/td_event_chest 첫 칸, 24×24 도트).
class ChestSprite extends StatelessWidget {
  const ChestSprite({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: size * 2,
        child: Image.asset(
          'assets/fx/td_event_chest.png',
          width: size * 2,
          height: size,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        ),
      ),
    ),
  );
}

/// 상자 보상 선택 창을 연다 (광고가 없으면 그냥 받는다). 사용자 2026-10-17: 왼쪽 알약 없이 상자를 누르면 작은 창만.
void showChestChoices(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(adOfferProvider(AdPlacement.chest))) {
    container.read(commandSinkProvider).send(const TapChest());
    return;
  }
  unawaited(
    showSkinDialog<void>(
      context,
      barrierColor: const Color(0x66000000),
      builder: (_) => const ChestChoicesSheet(),
    ),
  );
}

/// 작은 선택 창: 상자 · [그냥 받기 금액] [광고 ×n 금액(금빛)] · 아래 작은 '광고로 젬 n'. 상자가 가라앉으면 스스로 닫힌다.
class ChestChoicesSheet extends ConsumerWidget {
  const ChestChoicesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(gameStateProvider.select((s) => s.battle?.chest == null), (_, gone) {
      if (gone && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final reward = adDef(tables, AdPlacement.chest).reward;
    final mult = reward.number('value');
    final rewardOf = ref.watch(chestRewardProvider);
    final base = ref.watch(gameStateProvider.select(rewardOf));
    void close() => Navigator.of(context).pop();
    Widget option({
      required Key key,
      required SkinTone tone,
      required String top,
      required String amount,
      required VoidCallback onTap,
      bool ad = false,
    }) => Expanded(
      child: SkinButton(
        key: key,
        tone: tone,
        height: 76,
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ad) ...[const PixelSprite(UiSprites.ad, dots: 16, scale: 1), const SizedBox(width: 4)],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(top, style: Skin.text(16)),
                  ),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(amount, style: Skin.text(18)),
            ),
          ],
        ),
      ),
    );
    return Dialog(
      backgroundColor: Skin.card,
      insetPadding: popupInset,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        key: const Key('chest.sheet'),
        constraints: popupConstraints(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const ChestSprite(size: 32),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.uiChestTitle, style: Skin.text(20))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  option(
                    key: const Key('chest.take'),
                    tone: SkinTone.plain,
                    top: l10n.uiChestJustTake,
                    amount: base?.format() ?? '',
                    onTap: () {
                      ref.read(commandSinkProvider).send(const TapChest());
                      close();
                    },
                  ),
                  const SizedBox(width: 8),
                  // 광고 쪽이 이득 — 금빛 + '×n'.
                  option(
                    key: const Key('ad.chest.gold'),
                    tone: SkinTone.gold,
                    top: l10n.uiChestAdMult(shortDecimal(mult)),
                    amount: base?.times(mult).format() ?? '',
                    ad: true,
                    onTap: () {
                      unawaited(watchAd(ref, AdPlacement.chest, choice: 'gold'));
                      close();
                    },
                  ),
                ],
              ),
              TextButton(
                key: const Key('ad.chest.gems'),
                onPressed: () {
                  unawaited(watchAd(ref, AdPlacement.chest, choice: 'gems'));
                  close();
                },
                child: Text(l10n.uiChestAdGems(reward.integer('altGems')), style: Skin.text(14, color: Skin.sub)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
