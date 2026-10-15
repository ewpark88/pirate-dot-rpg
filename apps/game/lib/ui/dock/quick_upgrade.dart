import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 길게 누르면 이 간격으로 계속 강화한다.
const _repeatEvery = Duration(milliseconds: 160);

/// 지금 1회 강화로 전투력이 가장 많이 오르는 부품 (경제 previewUpgrade: (전투력 증가 ÷ 비용) 최대).
/// 전투력이 안 오르는 부품(화물칸)뿐이면 살 수 있는 것 중 가장 싼 것. 살 수 있는 게 없으면 null.
/// 골드 표시가 바뀔 때와 부품 레벨이 바뀔 때만 다시 계산한다(매 틱 계산하지 않게).
final quickUpgradeProvider = Provider<String?>((ref) {
  final tables = ref.watch(tablesProvider);
  ref.watch(
    gameStateProvider.select(
      (s) => '${s.wallet.gold.format()}|${[for (final p in tables.shipParts.parts) s.ship.level(p.id)].join(',')}',
    ),
  );
  final s = ref.read(gameStateProvider);
  String? best;
  var bestScore = 0.0;
  String? cheapest;
  BigNum? cheapestCost;
  for (final p in tables.shipParts.parts) {
    final preview = previewUpgrade(s, tables, p.id);
    if (preview.levels <= 0) continue;
    if (cheapestCost == null || preview.cost < cheapestCost) {
      cheapest = p.id;
      cheapestCost = preview.cost;
    }
    final gain = (preview.after.power - preview.before.power) / preview.cost;
    final score = gain.toDouble();
    if (score > bestScore) {
      best = p.id;
      bestScore = score;
    }
  }
  return best ?? cheapest;
});

/// 도크 옆 ‘빠른 강화’ (사용자 결정): 지금 가장 효율 좋은 부품 1회, 길게 누르면 연속. 살 게 없으면 회색.
class QuickUpgradeButton extends ConsumerStatefulWidget {
  const QuickUpgradeButton({super.key});

  @override
  ConsumerState<QuickUpgradeButton> createState() => _QuickUpgradeButtonState();
}

class _QuickUpgradeButtonState extends ConsumerState<QuickUpgradeButton> {
  Timer? _repeat;

  void _fire() {
    final part = ref.read(quickUpgradeProvider);
    if (part != null) ref.read(commandSinkProvider).send(UpgradePart(part));
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final part = ref.watch(quickUpgradeProvider);
    final tables = ref.watch(tablesProvider);
    final label = part == null
        ? l10n.uiQuickUpgradeNone
        : l10n.uiQuickUpgrade(tableText(l10n, tables.shipParts.byId(part).nameKey));
    final enabled = part != null;
    return TutorialSpot(
      id: 'quick.upgrade',
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('quick.upgrade'),
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _fire : null,
            onLongPressStart: enabled ? (_) => _repeat ??= Timer.periodic(_repeatEvery, (_) => _fire()) : null,
            onLongPressEnd: (_) => _stop(),
            onLongPressCancel: _stop,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enabled ? const [Skin.goldTop, Skin.goldBottom] : const [Skin.disabled, Skin.disabled],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: Skin.shadow,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (part != null)
                      PixelSprite(UiSprites.part(part), dots: 16)
                    else
                      const PixelSprite(UiSprites.lock, dots: 16),
                    const PixelBitmap(PixelBitmaps.up, color: Skin.goldInk, scale: 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
