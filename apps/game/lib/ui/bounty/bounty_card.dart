import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/bounty/bounty_sheet.dart';
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 현상금 사냥 화면 (기획 6절 ①②): 항해 탭 카드 + 현상금 시트.

/// 카드 최대 폭(dp) — 태블릿에서 너무 넓지 않게 (기획 6절 ⑤).
const _cardMaxWidth = 560.0;

String bossName(AppLocalizations l, WidgetRef ref, String id) =>
    tableText(l, ref.read(tablesProvider).regions.bosses[id]!.nameKey);

String weekName(AppLocalizations l, int weekday) => switch (weekday) {
  1 => l.uiWeek1,
  2 => l.uiWeek2,
  3 => l.uiWeek3,
  4 => l.uiWeek4,
  5 => l.uiWeek5,
  6 => l.uiWeek6,
  _ => l.uiWeek7,
};

String rewardText(AppLocalizations l, BountyReward r, int n) => switch (r) {
  BountyReward.gems => l.uiBountyRewardGems(n),
  BountyReward.cards => l.uiBountyRewardCards(n),
  BountyReward.gifts => l.uiBountyRewardGifts(n),
  BountyReward.mapPieces => l.uiBountyRewardMap(n),
};

String rewardIcon(BountyReward r) => switch (r) {
  BountyReward.gems => UiSprites.gem,
  BountyReward.cards => UiSprites.tabCrew,
  BountyReward.gifts => UiSprites.star,
  BountyReward.mapPieces => UiSprites.tabMap,
};

/// 보스 초상 (해역 보스 옆모습 그림 재사용 — 새 그림 없음). [dim]이면 흐리게(오늘 아닌 요일).
class BossPortrait extends StatelessWidget {
  const BossPortrait({required this.bossId, this.size = 56, this.dim = false, super.key});

  final String bossId;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dim ? 0.4 : 1,
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/bosses/$bossId.png',
        filterQuality: FilterQuality.none,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SkinIcon(UiSprites.flag, size: 32),
      ),
    ),
  );
}

/// 오늘 보여 줄 보스: 월~토 = 그 요일 보스. 일요일은 특정 보스를 고르지 않는다(S1 결정 — 추천 표시 없음),
/// 그림·시트 첫 선택만 표 순서 첫 보스(중립).
BountyDay todayBounty(int weekday) =>
    bountyDays.firstWhere((d) => d.weekday == weekday, orElse: () => bountyDays.first);

/// 항해 탭 카드 '현상금 사냥' (보물지도 카드 위): 오늘 보스·보상·티켓 n/9·[도전] [소탕 ×N]·티켓 0이면 [광고로 1장].
class BountyCard extends ConsumerWidget {
  const BountyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vm = ref.watch(bountyProvider);
    final weekday = ref.watch(bountyWeekdayProvider);
    final day = todayBounty(weekday);
    final sunday = weekday == DateTime.sunday;
    final best = vm.clearedOf(day.bossId);
    final control = ref.read(bountyProvider.notifier);
    void openSheet() => unawaited(showPixelSheet<void>(context, maxHeight: 0.85, builder: (_) => const BountySheet()));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
        child: GestureDetector(
          key: const Key('bounty.card'),
          behavior: HitTestBehavior.opaque,
          onTap: openSheet,
          child: SkinCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BossPortrait(bossId: day.bossId),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.uiBountyTitle, style: Skin.text(13, color: Skin.sub)),
                          Text(
                            sunday ? l10n.uiBountyAllBosses : bossName(l10n, ref, day.bossId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Skin.text(18),
                          ),
                          if (!sunday)
                            Row(
                              children: [
                                SkinIcon(rewardIcon(day.reward), size: 16),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    rewardText(l10n, day.reward, day.amountAt(vm.openTierOf(day.bossId))),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Skin.text(13, color: Skin.mintInk),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    BountyTicketPill(tickets: vm.tickets),
                  ],
                ),
                const SizedBox(height: 8),
                if (vm.tickets == 0)
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.uiBountyNoTicket, style: Skin.text(13, color: Skin.sub)),
                      ),
                      if (!vm.adUsedToday)
                        SkinButton(
                          key: const Key('bounty.ad'),
                          tone: SkinTone.gold,
                          onPressed: control.adTicket,
                          child: Text(l10n.uiBountyAdTicket),
                        ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SkinButton(
                          key: const Key('bounty.challenge'),
                          // 일요일은 보스를 시트에서 고른다.
                          onPressed: sunday ? openSheet : () => control.start(day.bossId, vm.openTierOf(day.bossId)),
                          child: Text(l10n.uiBountyChallenge),
                        ),
                      ),
                      if (best > 0 && !sunday) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: SkinButton(
                            key: const Key('bounty.sweep'),
                            tone: SkinTone.gold,
                            onPressed: () => control.sweep(day.bossId, vm.tickets),
                            child: Text(l10n.uiBountySweep(vm.tickets)),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BountyTicketPill extends StatelessWidget {
  const BountyTicketPill({required this.tickets, super.key});

  final int tickets;

  @override
  Widget build(BuildContext context) {
    final full = tickets >= bountyTicketCap;
    return Container(
      key: const Key('bounty.tickets'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: full ? const Color(0xFFFFE3E7) : Skin.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: full ? Skin.danger : Skin.goldBottom, width: 1.5),
      ),
      child: Text(
        AppLocalizations.of(context).uiBountyTickets(bountyTicketCap, tickets),
        style: Skin.text(13, color: full ? const Color(0xFFB0102A) : Skin.goldInk),
      ),
    );
  }
}
