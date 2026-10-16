import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/dock/quick_upgrade.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/badge_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 도크 높이(dp) — 전장 상자는 이 위에서 끝난다(시트가 닫혔을 때).
const double kDockHeight = 76;

/// 아래 엄지 자리 도크 (사용자 결정: 도크 + 끌어올리는 시트): 동그란 아이콘 4개(항해·배·선원·소환, 빨간 점) + 빠른 강화.
/// [open]은 지금 열린 패널(시트가 닫혔으면 null). 아이콘 키는 예전 탭과 같은 `tab.<i>`.
class HomeDock extends ConsumerWidget {
  const HomeDock({required this.open, required this.onTap, super.key});

  final int? open;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = [
      // 항해: 보물지도 상점에서 살 수 있는 칸이 있으면 점 1개 (환생 v2).
      (
        UiSprites.tabMap,
        l10n.uiTabVoyage,
        null,
        // 상점에서 살 수 있는 칸, 또는 현상금 티켓이 상한(9)일 때만 (넘치기 직전 = 지금 쓰면 이득).
        ref.watch(rebirthShopProvider.select((s) => s.anyAffordable)) ||
            ref.watch(bountyProvider.select((v) => v.tickets)) >= ref.watch(bountyLimitsProvider).ticketCap,
      ),
      (UiSprites.tabShip, l10n.uiTabShip, 'tab.ship', ref.watch(shipBadgeProvider)),
      (UiSprites.tabCrew, l10n.uiTabCrew, 'tab.crew', ref.watch(crewBadgeProvider)),
      (UiSprites.tabSummon, l10n.uiTabSummon, 'tab.summon', ref.watch(summonBadgeProvider)),
    ];
    return SizedBox(
      height: kDockHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, (asset, label, spot, badge)) in items.indexed) ...[
            _DockIcon(
              key: Key('tab.$i'),
              asset: asset,
              label: label,
              selected: open == i,
              // 지금 열린 패널에는 점을 띄우지 않는다.
              badge: badge && open != i,
              // 숫자 뱃지는 선원만 (스킨 r2 결정 ③).
              count: i == 2 ? ref.watch(crewBadgeCountProvider) : null,
              dotKey: Key('tab.dot.$i'),
              spot: spot,
              onTap: () => onTap(i),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 4),
          const QuickUpgradeButton(),
        ],
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.asset,
    required this.label,
    required this.selected,
    required this.badge,
    required this.dotKey,
    required this.spot,
    required this.onTap,
    this.count,
    super.key,
  });

  final String asset;
  final String label;
  final bool selected;
  final bool badge;
  final Key dotKey;
  final int? count;
  final String? spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget icon = PixelSprite(asset, dots: 16);
    if (spot case final id?) icon = TutorialSpot(id: id, child: icon);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 62,
          height: kDockHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PixelDot(
                show: badge,
                dotKey: dotKey,
                count: count,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  width: selected ? 54 : 50,
                  height: selected ? 54 : 50,
                  decoration: BoxDecoration(
                    color: selected ? Skin.skyDeep : Skin.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? Skin.primaryBottom : Colors.white, width: 2.5),
                    boxShadow: Skin.shadow,
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),
              ),
              const SizedBox(height: 1),
              Text(label, maxLines: 1, style: Skin.text(12, color: selected ? Skin.primaryEdge : Skin.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
