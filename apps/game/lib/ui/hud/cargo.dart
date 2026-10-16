import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 화물칸 = 골드 금고 용량 (S2 economy-cargo-capacity, 사용자 결정 2026-10-16): "화물칸이 가득 차 있다는 안내 문구를 보여 주고,
// 화물칸을 업그레이드하라는 경고". 자동 강화는 보상형 광고 10분으로만 ("자동 업그레이드 기능을 모두 빼고 수동으로만").

/// 금고 상태: 0 보통 · 1 거의 참(80% 이상, 노랑/주황) · 2 가득(빨강).
final cargoLevelProvider = Provider<int>((ref) {
  final t = ref.watch(tablesProvider);
  return ref.watch(
    gameStateProvider.select((s) {
      if (s.wallet.gold >= goldCapacity(s, t)) return 2;
      return goldNearFull(s, t) ? 1 : 0;
    }),
  );
});

/// 금고 채움 비율 (0~1, 막대). 2% 단위로만 다시 그린다.
final cargoRatioProvider = Provider<double>((ref) {
  final t = ref.watch(tablesProvider);
  return ref.watch(
    gameStateProvider.select((s) {
      final cap = goldCapacity(s, t);
      if (cap.isZero) return 1.0;
      final r = (s.wallet.gold / cap).toDouble().clamp(0.0, 1.0);
      return (r * 50).floor() / 50;
    }),
  );
});

Color cargoColor(int level) => switch (level) {
  2 => Skin.danger,
  1 => const Color(0xFFFF9F1C),
  _ => Skin.mint,
};

/// 상단 바 골드 아래 얇은 '현재 / 최대' 막대. 가득 차면 빨강 깜빡임(전장 틱 0.5초).
class GoldCapBar extends ConsumerWidget {
  const GoldCapBar({this.width = 56, super.key});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(cargoLevelProvider);
    final ratio = ref.watch(cargoRatioProvider);
    final blinkOff = level == 2 && ref.watch(gameStateProvider.select((s) => ((s.battle?.tick ?? 0) ~/ 10).isOdd));
    final s = ref.read(gameStateProvider);
    final cap = goldCapacity(s, ref.read(tablesProvider));
    return Semantics(
      label: AppLocalizations.of(context).uiCargoBar(s.wallet.gold.format(), cap.format()),
      excludeSemantics: true,
      child: Container(
        key: const Key('cargo.bar'),
        width: width,
        height: 5,
        decoration: BoxDecoration(color: Skin.track, borderRadius: BorderRadius.circular(3)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: ratio,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cargoColor(level).withValues(alpha: blinkOff ? 0.35 : 1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

/// 전장 알약 '화물칸 가득! 강화하세요' — 누르면 배 탭(화물칸 줄 강조).
class CargoFullPill extends ConsumerWidget {
  const CargoFullPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(cargoLevelProvider) < 2) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.uiCargoFullLong,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('cargo.full'),
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(dockTabRequestProvider.notifier).open(shipTabIndex),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 160, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xE6B3122E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.uiCargoFull,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Skin.text(13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 자동 강화: 버프 중이면 남은 시간 원형 칩(길게 누르면 다음 강화 부위), 아니면 광고 그림 버튼 '자동'(10분).
class AutoUpgradeChip extends ConsumerStatefulWidget {
  const AutoUpgradeChip({super.key});

  @override
  ConsumerState<AutoUpgradeChip> createState() => _AutoUpgradeChipState();
}

class _AutoUpgradeChipState extends ConsumerState<AutoUpgradeChip> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // 남은 시간은 상태가 안 바뀌어도 줄어든다 → 1초마다.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final now = ref.watch(clockProvider).now();
    final left = ref.watch(gameStateProvider.select((s) => autoUpgradeRemaining(s, now)));
    final reward = adDef(t, AdPlacement.autoUpgrade).reward;
    final full = Duration(seconds: reward.integer('durationSec'));
    if (left == Duration.zero) {
      return AdIconButton(
        placement: AdPlacement.autoUpgrade,
        label: l10n.uiAutoUpgradeAd(full.inMinutes),
        short: l10n.uiAutoUpgradeShort,
      );
    }
    final pick = ref.watch(gameStateProvider.select((s) => autoUpgradePick(s, t)));
    final time = remainingText(left);
    final max = Duration(seconds: reward.integer('maxStackSec'));
    return Tooltip(
      message: [
        l10n.uiAutoUpgradeLeft(time),
        if (pick != null) l10n.uiAutoUpgradeNext(tableText(l10n, t.shipParts.byId(pick).nameKey)),
      ].join('\n'),
      child: Container(
        key: const Key('autoUpgrade.on'),
        padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: Skin.shadowSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                value: (left.inSeconds / max.inSeconds).clamp(0.0, 1.0),
                strokeWidth: 3,
                backgroundColor: Skin.track,
                color: Skin.primaryBottom,
              ),
            ),
            const SizedBox(width: 4),
            Text(l10n.uiAutoUpgradeShort, style: Skin.text(13, color: Skin.primaryEdge)),
            const SizedBox(width: 4),
            Text(time, style: Skin.text(13)),
            // 끄기 (경제 CancelAutoUpgrade — 남은 시간은 버린다).
            GestureDetector(
              key: const Key('autoUpgrade.off'),
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(commandSinkProvider).send(const CancelAutoUpgrade()),
              child: Semantics(
                button: true,
                label: l10n.uiAutoUpgradeOff,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(6, 8, 2, 8),
                  child: Icon(Icons.close_rounded, size: 16, color: Skin.sub),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
