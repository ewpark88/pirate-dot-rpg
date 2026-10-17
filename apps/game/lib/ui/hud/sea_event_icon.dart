import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/fun_strips.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 돌발 이벤트(폭풍·금붕어 떼 등) = 떠 있는 띠 안 작은 아이콘 + 남은 시간 원 (S1 실기기 ④ 2026-10-17 — 알약 줄이
/// 화물칸 버튼과 겹쳐 전장 위가 3줄이 됐다). 누르면 이름·효과 한 줄.
class SeaEventIcon extends ConsumerStatefulWidget {
  const SeaEventIcon({super.key});

  @override
  ConsumerState<SeaEventIcon> createState() => _SeaEventIconState();
}

class _SeaEventIconState extends ConsumerState<SeaEventIcon> {
  final _countdown = FunCountdown();

  @override
  Widget build(BuildContext context) {
    final ev = ref.watch(gameStateProvider.select((s) => s.battle?.seaEvent));
    if (ev == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final (icon, text) = switch (ev.id) {
      'goldfish' => (UiSprites.coin, l10n.uiSeaGoldfish),
      'merchant' => (UiSprites.gem, l10n.uiSeaMerchant),
      'ambush' => (UiSprites.flag, l10n.uiSeaAmbush),
      'bottle' => (UiSprites.quest, l10n.uiSeaBottle),
      _ => (UiSprites.tailwind, l10n.uiSeaStorm),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        key: Key('fun.sea.${ev.id}'),
        message: text,
        triggerMode: TooltipTriggerMode.tap,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: _countdown.ratio(ev.id, ev.ticksLeft),
                  strokeWidth: 2.5,
                  color: const Color(0xFFFFD84A),
                  backgroundColor: Colors.black26,
                ),
              ),
              SkinIcon(icon, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
