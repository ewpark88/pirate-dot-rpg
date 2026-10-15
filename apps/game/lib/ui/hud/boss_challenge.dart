import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 파밍 중(보스를 못 잡아 제자리 항해)이면 전장 위에 ‘파밍 중’과 보스 도전 버튼 (설계서 4.1-4).
class BossChallenge extends ConsumerWidget {
  const BossChallenge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(
      gameStateProvider.select((s) => s.progress.farming && !(s.battle?.bossActive ?? false)),
    );
    if (!show) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 파밍 중 도트 띠.
        ColoredBox(
          color: PixelPalette.outline,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PixelSprite(UiSprites.farm, dots: 16, scale: 1),
                const SizedBox(width: 4),
                Text(l10n.uiFarming, style: const TextStyle(color: PixelPalette.text)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        TutorialSpot(
          id: 'boss.challenge',
          child: PixelButton(
            key: const Key('boss.challenge'),
            primary: true,
            onPressed: () => ref.read(commandSinkProvider).send(const ChallengeBoss()),
            child: Text(l10n.uiBossChallenge),
          ),
        ),
        const SizedBox(height: 4),
        const BossSupportAdButton(),
      ],
    );
  }
}
