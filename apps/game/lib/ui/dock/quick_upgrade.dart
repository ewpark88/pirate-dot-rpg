import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/hud/upgrade_float.dart';
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

/// 버튼에 보일 다음 강화: 부품·비용·모자란 골드(살 수 있으면 null). 살 게 없으면 가장 싼 부품을 흐리게 보인다.
typedef QuickTarget = ({String part, BigNum cost, BigNum? short});

final quickTargetProvider = Provider<QuickTarget?>((ref) {
  final tables = ref.watch(tablesProvider);
  final best = ref.watch(quickUpgradeProvider);
  final key = ref.watch(
    gameStateProvider.select(
      (s) => '${s.wallet.gold.format()}|${[for (final p in tables.shipParts.parts) s.ship.level(p.id)].join(',')}',
    ),
  );
  if (key.isEmpty) return null;
  final s = ref.read(gameStateProvider);
  var part = best;
  BigNum? cost;
  if (part == null) {
    // 살 수 있는 게 없음 → 최대 레벨이 아닌 부품 중 가장 싼 것.
    for (final p in tables.shipParts.parts) {
      final lv = s.ship.level(p.id);
      if (p.maxLevel != null && lv >= p.maxLevel!) continue;
      final c = partCost(p, lv);
      if (cost == null || c < cost) {
        cost = c;
        part = p.id;
      }
    }
  } else {
    cost = partCost(tables.shipParts.byId(part), s.ship.level(part));
  }
  if (part == null || cost == null) return null;
  final short = s.wallet.gold >= cost ? null : cost - s.wallet.gold;
  return (part: part, cost: cost, short: short);
});

/// 도크 옆 ‘빠른 강화’ (사용자 결정): 지금 가장 효율 좋은 부품 1회, 길게 누르면 연속. 살 게 없으면 회색.
class QuickUpgradeButton extends ConsumerStatefulWidget {
  const QuickUpgradeButton({super.key});

  @override
  ConsumerState<QuickUpgradeButton> createState() => _QuickUpgradeButtonState();
}

class _QuickUpgradeButtonState extends ConsumerState<QuickUpgradeButton> with SingleTickerProviderStateMixin {
  Timer? _repeat;
  StreamSubscription<RecordedTick>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is PartUpgraded && mounted) {
          final l10n = AppLocalizations.of(context);
          final name = tableText(l10n, ref.read(tablesProvider).shipParts.byId(e.part).nameKey);
          // '+대포 Lv 53'(사용자 지시: 업그레이드됐는지 보이게) — 전장 배 체력 막대 위에 떠오른다(UpgradeFloatLabel).
          ref.read(upgradeFloatProvider.notifier).show(l10n.uiQuickUpgradeDone(e.level, name));
        }
      }
    });
  }

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
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final part = ref.watch(quickUpgradeProvider);
    final target = ref.watch(quickTargetProvider);
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
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: enabled ? const [Skin.goldTop, Skin.goldBottom] : const [Skin.disabled, Skin.disabled],
                    ),
                    border: Border.all(color: Skin.outline, width: 3),
                    boxShadow: Skin.shadow,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (target != null)
                          Opacity(
                            opacity: part == null ? 0.5 : 1,
                            child: PixelSprite(UiSprites.part(target.part), dots: 16),
                          )
                        else
                          const PixelSprite(UiSprites.lock, dots: 16),
                        const PixelBitmap(PixelBitmaps.up, color: Skin.goldInk, scale: 1),
                      ],
                    ),
                  ),
                ),
                // 비용(또는 모자란 골드) 알약 — 버튼 아래.
                if (target != null)
                  Positioned(
                    bottom: -8,
                    child: Container(
                      key: const Key('quick.upgrade.cost'),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: target.short == null ? Skin.ink : const Color(0xFF8A8F99),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Skin.outline, width: 1.5),
                      ),
                      child: Text(
                        target.short == null ? target.cost.format() : l10n.uiQuickUpgradeShort(target.short!.format()),
                        style: Skin.outlined(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
