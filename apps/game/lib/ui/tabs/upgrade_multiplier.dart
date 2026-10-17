import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 일괄 강화 배수 (S1 지시): 1 · 5 · 10 · 20 · 50 · MAX(0). 화면 상태라 세이브에 남지 않는다.
const upgradeMultipliers = [1, 5, 10, 20, 50, 0];

final upgradeMultiplierProvider = NotifierProvider<UpgradeMultiplier, int>(UpgradeMultiplier.new);

class UpgradeMultiplier extends Notifier<int> {
  @override
  int build() => 1;

  // ignore: use_setters_to_change_properties — 화면에서 고르는 동작이라 메서드로 둔다.
  void pick(int n) => state = n;
}

/// 이 배수로 [def]를 Lv[level]에서 강화하면: (실제로 살 레벨 수, 보여 줄 비용).
/// 골드가 모자라면 살 수 있는 만큼(경제 UpgradePart와 같은 규칙). 하나도 못 사면 레벨 0, 비용은 목표만큼(MAX는 1회) — 회색 버튼에 쓴다.
(int levels, BigNum cost) bulkUpgrade(ShipPartDef def, int level, BigNum gold, int multiplier) {
  final can = affordableLevels(def, level, gold);
  final room = def.maxLevel == null ? multiplier : (def.maxLevel! - level);
  final want = multiplier == 0 ? 1 : (room < multiplier ? room : multiplier);
  final levels = multiplier == 0 ? can : (can < want ? can : want);
  return (levels, partCostSum(def, level, levels > 0 ? levels : want));
}

/// 커맨드: 배수 0이면 '최대'.
Command bulkUpgradeCommand(String part, int multiplier) =>
    multiplier == 0 ? UpgradePart.max(part) : UpgradePart(part, times: multiplier);

/// 배 탭 위 배수 알약 줄 [×1 · ×5 · ×10 · ×20 · ×50 · MAX].
class UpgradeMultiplierPills extends ConsumerWidget {
  const UpgradeMultiplierPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(upgradeMultiplierProvider);
    return Container(
      key: const Key('ship.mult'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Skin.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
        boxShadow: Skin.shadowSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in upgradeMultipliers)
            Semantics(
              button: true,
              selected: now == n,
              child: GestureDetector(
                key: Key('ship.mult.${n == 0 ? 'max' : n}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(upgradeMultiplierProvider.notifier).pick(n),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: now == n ? Skin.primaryBottom : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      n == 0 ? l10n.uiMultMax : l10n.uiMult(n),
                      style: Skin.outlined(15, color: now == n ? Colors.white : const Color(0xFFF1F0FF)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
