import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// '모두 강화' 원터치 (사용자 2026-10-17 '금화가 상한에 너무 빨리 차서 레벨업 반복이 귀찮다'):
// 계획은 경제 bestUpgradePlan(자동 강화와 같은 규칙)만 쓴다 — 누를 때 한 번 계산하고 부위마다 UpgradePart(times: n)를 보낸다.

/// 지금 살 수 있는 강화가 하나라도 있나 (가벼운 판정 — 계획은 누를 때만 계산).
final canUpgradeAnyProvider = Provider<bool>((ref) {
  final t = ref.watch(tablesProvider);
  return ref.watch(gameStateProvider.select((s) => autoUpgradePick(s, t) != null));
});

/// 모두 강화: 계획대로 보내고 '대포 +3 · 선체 +2' 토스트. 살 것이 없으면 아무것도 안 한다.
void upgradeAll(BuildContext context, WidgetRef ref) {
  final t = ref.read(tablesProvider);
  final plan = bestUpgradePlan(ref.read(gameStateProvider), t);
  if (plan.levels.isEmpty) return;
  final sink = ref.read(commandSinkProvider);
  final l10n = AppLocalizations.of(context);
  // 표 순서대로(대포 → 선체 → …) 보내고 같은 순서로 보인다.
  final done = [
    for (final p in t.shipParts.parts)
      if (plan.levels[p.id] case final n?) (p, n),
  ];
  for (final (p, n) in done) {
    sink.send(UpgradePart(p.id, times: n));
  }
  showSkinToast(context, done.map((e) => l10n.uiUpgradeAllPart(tableText(l10n, e.$1.nameKey), e.$2)).join(' · '));
}

/// 배 탭 위쪽 큰 '모두 강화' 버튼 (56dp, 금색). 살 것이 없으면 흐리게.
class UpgradeAllButton extends ConsumerWidget {
  const UpgradeAllButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(canUpgradeAnyProvider);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: SkinButton(
        key: const Key('upgradeAll'),
        tone: SkinTone.gold,
        height: 56,
        onPressed: on ? () => upgradeAll(context, ref) : null,
        // 배 헤더 안(좁은 칸)에서도 한 줄 — 넘치면 줄여 맞춘다.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard_double_arrow_up_rounded, size: 24, color: Skin.goldInk),
              const SizedBox(width: 6),
              Text(l10n.uiUpgradeAll, style: Skin.text(18, color: Skin.goldInk)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전장 왼쪽 위 '화물칸 가득' 알약 옆 작은 '모두 강화' 알약 — 배 탭을 열지 않고 바로.
class UpgradeAllPill extends ConsumerWidget {
  const UpgradeAllPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canUpgradeAnyProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.uiUpgradeAll,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('upgradeAll.pill'),
        behavior: HitTestBehavior.opaque,
        onTap: () => upgradeAll(context, ref),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Skin.goldTop, Skin.goldBottom]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Skin.outline, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard_double_arrow_up_rounded, size: 16, color: Skin.goldInk),
              const SizedBox(width: 3),
              Text(l10n.uiUpgradeAll, style: Skin.text(13, color: Skin.goldInk)),
            ],
          ),
        ),
      ),
    );
  }
}
