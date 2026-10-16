import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 사용자 직접 지시 2026-10-16: 보물상자의 '젬×30·골드' 말풍선이 크고 캐릭터·전투를 가린다 → 말풍선 삭제.
// 광고 제안은 전장 왼쪽 가장자리의 작은 알약 하나(상자 그림 + 골드·젬 그림, 글자 없음, 높이 40dp).
// 알약이나 상자를 누르면 작은 선택 시트(그냥 받기 / 광고 골드 / 광고 젬).

/// 가장자리 알약 크기(dp) — 전장 폭 20% 안(360dp 전장 = 72dp)에 들어간다.
const chestPillSize = Size(58, 40);

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

/// 전장 왼쪽 가장자리 알약: [상자] [골드·젬]. 누르면 선택 시트.
class ChestEdgePill extends ConsumerWidget {
  const ChestEdgePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(chestOfferProvider)) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).uiChestPill,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('chest.pill'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showChestChoices(context),
        child: Container(
          width: chestPillSize.width,
          height: chestPillSize.height,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(chestPillSize.height / 2),
            border: Border.all(color: Skin.goldBottom, width: 2),
            boxShadow: Skin.shadow,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChestSprite(),
              SizedBox(width: 2),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkinIcon(UiSprites.coin, size: 13),
                  SkinIcon(UiSprites.gem, size: 13),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상자 보상 선택 시트를 연다 (광고가 없으면 그냥 받는다).
void showChestChoices(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(adOfferProvider(AdPlacement.chest))) {
    container.read(commandSinkProvider).send(const TapChest());
    return;
  }
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // 테마의 시트 판·테두리 없이 카드 하나만.
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      showDragHandle: false,
      builder: (_) => const ChestChoicesSheet(),
    ),
  );
}

/// 작은 선택 시트: 제목 · [그냥 받기] · 광고 [골드 ×5] [젬]. 상자가 가라앉으면 스스로 닫힌다.
class ChestChoicesSheet extends ConsumerWidget {
  const ChestChoicesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(gameStateProvider.select((s) => s.battle?.chest == null), (_, gone) {
      if (gone && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
    final l10n = AppLocalizations.of(context);
    final rewardOf = ref.watch(chestRewardProvider);
    final base = ref.watch(gameStateProvider.select(rewardOf));
    return SafeArea(
      child: Container(
        key: const Key('chest.sheet'),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Skin.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Skin.shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const ChestSprite(size: 32),
                const SizedBox(width: 8),
                Text(l10n.uiChestTitle, style: Skin.text(18)),
              ],
            ),
            const SizedBox(height: 10),
            // 광고: 골드 ×5 · 젬 (기존 버튼 그대로 — 결과는 경제가 상자를 열며 준다).
            const ChestAdButtons(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SkinButton(
                key: const Key('chest.take'),
                height: 44,
                onPressed: () {
                  ref.read(commandSinkProvider).send(const TapChest());
                  Navigator.of(context).pop();
                },
                child: Text(l10n.uiChestTake(base?.format() ?? '')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
