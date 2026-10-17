import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart';
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

/// 현상금 시트: 요일 7칸(오늘 강조, 일요일 전부 열림, 태블릿 한 줄 · 폰 4+3) · 단계 − t + · 다음 단계 진행 막대 · 도전.
class BountySheet extends ConsumerStatefulWidget {
  const BountySheet({super.key});

  @override
  ConsumerState<BountySheet> createState() => _BountySheetState();
}

class _BountySheetState extends ConsumerState<BountySheet> {
  String? _boss;
  int? _tier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = ref.watch(bountyProvider);
    final weekday = ref.watch(bountyWeekdayProvider);
    final days = ref.watch(bountyDaysProvider);
    final day = days.firstWhere((d) => d.bossId == _boss, orElse: () => todayBounty(days, weekday));
    final open = bountyOpenOn(weekday, day);
    final best = vm.clearedOf(day.bossId);
    final tier = (_tier ?? vm.openTierOf(day.bossId)).clamp(1, vm.openTierOf(day.bossId));
    // 태블릿(UI 배율 뒤 논리 폭 ≥ 540, app.dart 넓은 화면 기준) = 7칸 한 줄.
    final wide = MediaQuery.sizeOf(context).width >= 540;
    final control = ref.read(bountyCommandsProvider);

    Widget cell(int wd) {
      final d = days.where((x) => x.weekday == wd).firstOrNull;
      final selected = d != null && d.bossId == day.bossId;
      final today = wd == weekday;
      return Expanded(
        child: GestureDetector(
          key: Key('bounty.day.$wd'),
          behavior: HitTestBehavior.opaque,
          onTap: d == null
              ? null
              : () => setState(() {
                  _boss = d.bossId;
                  _tier = null;
                }),
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: today ? Skin.goldTop : Skin.insetFill, // k2: 연보라 칸 + 굵은 외곽선, 오늘은 금, 고른 칸은 파랑 테
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Skin.primaryBottom : Skin.outline,
                width: selected ? 3 : Skin.outlineWidth,
              ),
            ),
            child: Column(
              children: [
                Text(weekName(l10n, wd), style: Skin.text(13, color: today ? Skin.goldInk : Skin.ink)),
                const SizedBox(height: 2),
                if (d == null)
                  const SkinIcon(UiSprites.star, size: 30)
                else
                  BossPortrait(bossId: d.bossId, size: 34, dim: !bountyOpenOn(weekday, d)),
                const SizedBox(height: 2),
                Text(
                  d == null ? '★' : l10n.uiBountyTier(vm.clearedOf(d.bossId)),
                  style: Skin.text(11, color: Skin.sub),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final weekdays = [for (var wd = 1; wd <= 7; wd++) wd];
    // 작은 폰·가로 공간이 부족하면 시트 안에서 스크롤.
    return SingleChildScrollView(
      child: Column(
        key: const Key('bounty.sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SubRibbon(l10n.uiBountyTitle)),
              BountyTicketPill(tickets: vm.tickets, cap: ref.watch(bountyLimitsProvider).ticketCap),
            ],
          ),
          if (weekday == DateTime.sunday)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l10n.uiBountyAnyBoss, style: Skin.text(13, color: Skin.mintInk)),
            ),
          const SizedBox(height: 8),
          // 태블릿 = 7칸 한 줄, 폰 = 4 + 3 두 줄.
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final wd in weekdays) cell(wd)])
          else ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final wd in weekdays.take(4)) cell(wd)]),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final wd in weekdays.skip(4)) cell(wd), const Spacer()],
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: Skin.inset(radius: Skin.radiusCard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BossPortrait(bossId: day.bossId, size: 48, dim: !open),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bossName(l10n, ref, day.bossId), style: Skin.text(18)),
                          Text(
                            best > 0 ? l10n.uiBountyBest(best) : l10n.uiBountyNotCleared,
                            style: Skin.text(13, color: Skin.sub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 단계 − t +
                Row(
                  children: [
                    _Step(
                      key: const Key('bounty.tier.minus'),
                      icon: Icons.remove_rounded,
                      onTap: tier > 1 ? () => setState(() => _tier = tier - 1) : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(l10n.uiBountyTier(tier), key: const Key('bounty.tier'), style: Skin.text(20)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SkinIcon(rewardIcon(day.reward), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                rewardText(l10n, day.reward, day.amountAt(tier)),
                                style: Skin.text(14, color: Skin.mintInk),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _Step(
                      key: const Key('bounty.tier.plus'),
                      icon: Icons.add_rounded,
                      onTap: tier < vm.openTierOf(day.bossId) ? () => setState(() => _tier = tier + 1) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 다음 단계 진행 (실패해도 입힌 피해만큼 — 참고용).
                Text(
                  l10n.uiBountyProgress(((vm.progress[day.bossId] ?? 0) * 100).round()),
                  style: Skin.text(12, color: Skin.sub),
                ),
                const SizedBox(height: 3),
                SkinBar(value: vm.progress[day.bossId] ?? 0, color: Skin.goldBottom, height: 8),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SkinButton(
                    key: const Key('bounty.sheet.challenge'),
                    height: 50,
                    onPressed: open && vm.tickets > 0
                        ? () {
                            if (control.start(day.bossId, tier)) Navigator.of(context).pop();
                          }
                        : null,
                    child: Text(open ? l10n.uiBountyChallenge : l10n.uiBountyClosed),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onTap == null ? Skin.track : Skin.plainBottom,
          shape: BoxShape.circle,
          border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
        ),
        child: Icon(icon, color: onTap == null ? Skin.disabled : Skin.ink),
      ),
    ),
  );
}
