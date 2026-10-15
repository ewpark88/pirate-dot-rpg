import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/fun_strips.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 유리병 쪽지 3장 (전장 안 말풍선 — 아래 패널을 덮지 않음): 누르면 PickBottle(i). 10초가 지나면 엔진이 첫 쪽지를 고른다.
class BottleChoices extends ConsumerStatefulWidget {
  const BottleChoices({super.key});

  @override
  ConsumerState<BottleChoices> createState() => _BottleChoicesState();
}

class _BottleChoicesState extends ConsumerState<BottleChoices> {
  final _countdown = FunCountdown();

  @override
  Widget build(BuildContext context) {
    final ev = ref.watch(gameStateProvider.select((s) => s.battle?.seaEvent));
    if (ev == null || ev.id != 'bottle' || ev.choices.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final left = _countdown.ratio('bottle', ev.ticksLeft);
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final (i, kind) in ev.choices.indexed)
                _Bubble(
                  key: Key('fun.bottle.$i'),
                  icon: switch (kind) {
                    'gold' => UiSprites.coin,
                    'tailwind' => UiSprites.tailwind,
                    _ => UiSprites.gem,
                  },
                  label: switch (kind) {
                    'gold' => l10n.uiBottleGold,
                    'tailwind' => l10n.uiBottleTailwind,
                    _ => l10n.uiBottleGift,
                  },
                  onTap: () => ref.read(commandSinkProvider).send(PickBottle(i)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                key: const Key('fun.bottle.timer'),
                value: left.clamp(0.0, 1.0),
                minHeight: 5,
                color: Skin.goldTop,
                backgroundColor: Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.label, required this.onTap, super.key});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF5), Color(0xFFF3E7C6)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: Skin.shadow,
        ),
        child: Column(
          children: [
            SkinIcon(icon, size: 30),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: Skin.text(13)),
          ],
        ),
      ),
    ),
  );
}
