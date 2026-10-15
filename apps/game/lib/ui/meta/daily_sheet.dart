import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/daily_providers.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 지금 퀘스트·출석 화면 값. 경제 함수(B7·B8)가 오기 전에는 (null, null).
(List<QuestView>?, AttendanceView?) _daily(WidgetRef ref) {
  final state = ref.watch(gameStateProvider);
  return (
    ref.watch(dailyQuestsProvider)(state),
    ref.watch(attendanceProvider)(state, ref.watch(clockProvider).now()),
  );
}

bool _claimable(QuestView q) => q.done && !q.claimed;

/// 전장 위 퀘스트·출석 아이콘 1개 (설계서 4.12). 받을 것이 있으면 빨간 점 (4.9: 지금 눌러서 이득일 때만).
class DailyIcon extends ConsumerWidget {
  const DailyIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (quests, attendance) = _daily(ref);
    if (quests == null && attendance == null) return const SizedBox.shrink();
    final claimable = (quests?.any(_claimable) ?? false) || (attendance != null && !attendance.claimedToday);
    final icon = PixelButton(
      key: const Key('daily.icon'),
      semanticLabel: AppLocalizations.of(context).uiDailyTooltip,
      child: const PixelSprite(UiSprites.quest, dots: 16, scale: 1),
      onPressed: () => unawaited(showPixelSheet<void>(context, builder: (_) => const DailySheet())),
    );
    return claimable ? PixelDot(key: const Key('daily.dot'), child: icon) : icon;
  }
}

/// 하단 시트: 위 칸 일일 퀘스트 4줄(줄마다 받기), 아래 칸 출석 7칸.
class DailySheet extends ConsumerWidget {
  const DailySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (quests, attendance) = _daily(ref);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (quests != null) _Quests(quests),
        if (quests != null && attendance != null) const _DotRule(),
        if (attendance != null) _Attendance(attendance),
      ],
    );
  }
}

class _Quests extends ConsumerWidget {
  const _Quests(this.quests);

  final List<QuestView> quests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    String name(QuestView q) => switch (q.type) {
      'kill' => l10n.uiQuestKill(q.target),
      'upgrade' => l10n.uiQuestUpgrade(q.target),
      'summon' => l10n.uiQuestSummon(q.target),
      _ => l10n.uiQuestAd(q.target),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.uiQuestTitle, style: Theme.of(context).textTheme.titleMedium),
        for (final q in quests)
          // 퀘스트 한 줄: 체크 · 이름/진행 · 받기 (ListTile 대신).
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                PixelSprite(q.done ? UiSprites.check : UiSprites.checkEmpty, dots: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name(q)),
                      Text(
                        l10n.uiQuestProgress(q.progress, q.target),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: PixelPalette.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (q.claimed)
                  Text(l10n.uiQuestClaimed, style: const TextStyle(color: PixelPalette.textDim))
                else
                  PixelButton(
                    key: Key('daily.claim.${q.id}'),
                    primary: true,
                    onPressed: _claimable(q) ? () => ref.read(commandSinkProvider).send(ClaimDaily(q.id)) : null,
                    child: Text(l10n.uiQuestClaimGems(ref.watch(tablesProvider).meta.dailyQuestRewardGems)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Attendance extends ConsumerWidget {
  const _Attendance(this.view);

  final AttendanceView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.uiAttendanceTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        // 7일차 문구가 길어도 칸 높이를 맞춘다.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < view.rewards.length; i++)
                Expanded(
                  child: _DayCell(day: i + 1, reward: view.rewards[i], view: view),
                ),
            ],
          ),
        ),
        if (!view.claimedToday)
          Align(
            alignment: Alignment.centerRight,
            child: PixelButton(
              key: const Key('attendance.claim'),
              primary: true,
              onPressed: () => ref.read(commandSinkProvider).send(const ClaimAttendance()),
              child: Text(l10n.uiAttendanceClaim),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.reward, required this.view});

  final int day;

  /// `meta.attendance.rewards`의 한 칸: `gems` 또는 `summon`+`minRarity`(영웅 이상 확정 소환).
  final JsonReader reward;
  final AttendanceView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = day == view.day;
    final ticket = !reward.has('gems');
    // 출석은 하루 빠져도 이어서 받는다(리셋 없음) — 지난 날은 모두 받은 칸.
    final checked = day < view.day || (today && view.claimedToday);
    // 도트 칸: 오늘은 금색 2칸 테두리(아직 안 받았으면 파란 바탕), 나머지는 1칸 테두리.
    return Padding(
      key: Key('attendance.day.$day.${checked ? 'checked' : (today ? 'today' : 'later')}'),
      padding: const EdgeInsets.all(2),
      child: PixelFrame(
        fill: today && !checked ? PixelPalette.actionDark : PixelPalette.navy,
        border: today ? PixelPalette.gold : PixelPalette.border,
        borderDots: today ? 2 : 1,
        highlight: null,
        child: Column(
          children: [
            Text(l10n.uiAttendanceDay(day), style: Theme.of(context).textTheme.labelSmall),
            if (checked)
              const PixelSprite(UiSprites.check, dots: 8)
            else if (ticket)
              const PixelSprite(UiSprites.tabSummon, dots: 16, scale: 1)
            else
              const PixelSprite(UiSprites.gem, dots: 8, frames: 3),
            if (ticket)
              Text(
                l10n.uiAttendanceTicket,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              )
            else
              Text(reward.integer('gems').toString(), style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// 칸 나눔 1칸 도트 줄 (Divider 대신).
class _DotRule extends StatelessWidget {
  const _DotRule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: SizedBox(
      height: pixelUnit(context),
      child: const ColoredBox(color: PixelPalette.border),
    ),
  );
}
