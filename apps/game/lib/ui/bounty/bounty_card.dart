import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart' show AdPlacement;
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/hd/hd_portrait.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
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

String rewardText(AppLocalizations l, BountyRewardKind r, int n) => switch (r) {
  BountyRewardKind.gems => l.uiBountyRewardGems(n),
  BountyRewardKind.cards => l.uiBountyRewardCards(n),
  BountyRewardKind.gifts => l.uiBountyRewardGifts(n),
  BountyRewardKind.mapPieces => l.uiBountyRewardMap(n),
};

String rewardIcon(BountyRewardKind r) => switch (r) {
  BountyRewardKind.gems => UiSprites.gem,
  BountyRewardKind.cards => UiSprites.tabCrew,
  BountyRewardKind.gifts => UiSprites.star,
  BountyRewardKind.mapPieces => UiSprites.tabMap,
};

/// 보스 초상: HD 카툰(HdPortrait) — HD가 아닌 보스는 해역 보스 옆모습 도트 그림. [dim]이면 흐리게(오늘 아닌 요일).
class BossPortrait extends StatelessWidget {
  const BossPortrait({required this.bossId, this.size = 56, this.dim = false, super.key});

  final String bossId;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dim ? 0.4 : 1,
    // HD 카툰 보스면 HD 초상(전장과 같은 그림), 아니면 해역 보스 도트 그림.
    child: HdPortrait(
      kind: bossId,
      boss: true,
      size: size,
      fallback: Image.asset(
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
BountyDay todayBounty(List<BountyDay> days, int weekday) =>
    days.firstWhere((d) => d.weekday == weekday, orElse: () => days.first);

/// 항해 탭 카드 '현상금 사냥' (보물지도 카드 위): 오늘 보스·보상·티켓 n/9·[도전] [소탕 ×N]·티켓 0이면 [광고로 1장].
class BountyCard extends ConsumerWidget {
  const BountyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vm = ref.watch(bountyProvider);
    final weekday = ref.watch(bountyWeekdayProvider);
    final day = todayBounty(ref.watch(bountyDaysProvider), weekday);
    final sunday = weekday == DateTime.sunday;
    final best = vm.clearedOf(day.bossId);
    final control = ref.read(bountyCommandsProvider);
    void openSheet() => unawaited(showPixelSheet<void>(context, maxHeight: 0.85, builder: (_) => const BountySheet()));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
        child: GestureDetector(
          key: const Key('bounty.card'),
          behavior: HitTestBehavior.opaque,
          onTap: openSheet,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: Skin.inset(radius: Skin.radiusCard),
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
                    BountyTicketPill(tickets: vm.tickets, cap: ref.watch(bountyLimitsProvider).ticketCap),
                  ],
                ),
                const SizedBox(height: 8),
                if (vm.tickets == 0)
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.uiBountyNoTicket, style: Skin.text(13, color: Skin.sub)),
                      ),
                      // 광고로 티켓 1장 (경제가 하루 1번을 지킨다 — 제안할 수 없으면 버튼이 안 보인다).
                      // 광고 장치가 표(ads.json)에 있을 때만 — 없으면 경제 canWatchAd가 실패한다.
                      if (!vm.adUsedToday &&
                          ref.watch(tablesProvider).ads.placements.any((d) => d.id == AdPlacement.bountyTicket.name))
                        AdButton(
                          key: const Key('bounty.ad'),
                          placement: AdPlacement.bountyTicket,
                          label: l10n.uiBountyAdTicket,
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
  const BountyTicketPill({required this.tickets, required this.cap, super.key});

  final int tickets;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final full = tickets >= cap;
    return Container(
      key: const Key('bounty.tickets'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: full ? const Color(0xFFFFE3E7) : Skin.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: full ? Skin.danger : Skin.outline, width: 2),
      ),
      child: Text(
        AppLocalizations.of(context).uiBountyTickets(cap, tickets),
        style: Skin.text(13, color: full ? const Color(0xFFB0102A) : Skin.goldInk),
      ),
    );
  }
}
