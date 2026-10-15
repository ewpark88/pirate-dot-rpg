import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/flags.dart';
import 'package:pirate_dot/operator/operator_gate.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/hud/tailwind_badge.dart';
import 'package:pirate_dot/ui/meta/daily_sheet.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_icon_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/settings/settings_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 상단 바 (전장 밖, layout-v2-brief 1): 왼쪽 골드·젬, 순풍 칩 + 광고 그림 버튼(순풍·파밍 중 함포 지원),
/// 오른쪽 퀘스트·설정 그림 버튼. 누르는 영역이 48dp라 바 높이도 48dp.
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (gold, gems) = ref.watch(gameStateProvider.select((s) => (s.wallet.gold, s.wallet.gems)));
    final u = pixelUnit(context);
    final money = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PixelSprite(UiSprites.coin, dots: 16, scale: 1),
        const SizedBox(width: 4),
        Text(
          gold.format(),
          key: const Key('top.gold'),
          style: const TextStyle(color: PixelPalette.gold),
        ),
        const SizedBox(width: 10),
        const PixelSprite(UiSprites.gem, dots: 8, frames: 3),
        const SizedBox(width: 4),
        Text(gems.toString(), key: const Key('top.gems')),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PixelPalette.navyDark,
        border: Border(
          bottom: BorderSide(color: PixelPalette.border, width: u),
        ),
      ),
      child: SizedBox(
        height: kMinTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              // 운영자 빌드에서만 골드 글자 5번 → 운영자 패널. 배포 빌드에는 제스처가 없다.
              if (kOperator) OperatorTapGate(child: money) else money,
              const SizedBox(width: 8),
              // 순풍·광고는 남는 폭 안에서만 (좁으면 줄여서 넣는다).
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [TailwindBadge(), TailwindAdButton(), BossSupportAdButton()],
                  ),
                ),
              ),
              const DailyIcon(),
              PixelIconButton(
                key: const Key('hud.settings'),
                asset: UiSprites.gear,
                semanticLabel: l10n.uiSettingsTitle,
                onPressed: () => unawaited(
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
