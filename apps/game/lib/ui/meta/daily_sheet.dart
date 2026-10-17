import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/daily_attendance.dart';
import 'package:pirate_dot/ui/meta/daily_providers.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_icon_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/build_counter.dart';
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

/// 받을 수 있는 퀘스트 + 오늘 출석 수(퀘스트·출석이 아직 없으면 −1). 늘 보이는 아이콘이 쓰므로 숫자만 구독한다
/// — 상태 전체를 보면 엔진 틱마다 다시 짓는다(사용자 버그 2026-10-16 버벅임).
int dailyClaimCount(WidgetRef ref) {
  final questsOf = ref.watch(dailyQuestsProvider);
  final attendanceOf = ref.watch(attendanceProvider);
  final now = ref.watch(clockProvider).now();
  return ref.watch(
    gameStateProvider.select((s) {
      final quests = questsOf(s);
      final attendance = attendanceOf(s, now);
      if (quests == null && attendance == null) return -1;
      // 받을 수 있는 수 (스킨 r2 숫자 뱃지: 퀘스트 + 오늘 출석).
      return (quests?.where(_claimable).length ?? 0) + (attendance != null && !attendance.claimedToday ? 1 : 0);
    }),
  );
}

/// 퀘스트·출석 시트 열기(도크 '퀘스트' 칸 — 사용자 피드백 #9 A, 엄지 닿는 아래로).
void openDailySheet(BuildContext context) =>
    unawaited(showPixelSheet<void>(context, builder: (_) => const DailySheet()));

/// 퀘스트·출석 아이콘 1개 (설계서 4.12). 받을 것이 있으면 빨간 점 (4.9: 지금 눌러서 이득일 때만).
class DailyIcon extends ConsumerWidget {
  const DailyIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    countBuild('dailyIcon');
    final count = dailyClaimCount(ref);
    if (count < 0) return const SizedBox.shrink();
    final icon = PixelIconButton(
      key: const Key('daily.icon'),
      asset: UiSprites.quest,
      semanticLabel: AppLocalizations.of(context).uiDailyTooltip,
      onPressed: () => openDailySheet(context),
    );
    return count > 0 ? PixelDot(key: const Key('daily.dot'), count: count, child: icon) : icon;
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
        if (attendance != null) DailyAttendance(attendance),
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
        SubRibbon(l10n.uiQuestTitle),
        for (final q in quests)
          // 퀘스트 한 줄: 체크 · 이름/진행 · 받기 — k2 안쪽 판(굵은 외곽선, 다 한 줄은 연초록).
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: Skin.inset(fill: q.done && !q.claimed ? const Color(0xFFDDF7EA) : Skin.insetFill),
            child: Row(
              children: [
                SkinIcon(q.done ? UiSprites.check : UiSprites.checkEmpty, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name(q), style: Skin.bold(15)),
                      Text(
                        l10n.uiQuestProgress(q.progress, q.target),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: PixelPalette.textDim),
                      ),
                      // 진행 막대 (r2 최종 다듬기).
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          key: Key('daily.bar.${q.id}'),
                          value: q.target == 0 ? 1 : (q.progress / q.target).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: Skin.track,
                          color: q.done ? Skin.mint : Skin.primaryBottom,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (q.claimed)
                  // 받음: 초록 체크 알약.
                  Container(
                    key: Key('daily.claimed.${q.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF7EA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 16, color: Skin.mintInk),
                        const SizedBox(width: 3),
                        Text(l10n.uiQuestClaimed, style: Skin.text(13, color: Skin.mintInk)),
                      ],
                    ),
                  )
                else
                  PixelButton(
                    key: Key('daily.claim.${q.id}'),
                    primary: true,
                    onPressed: _claimable(q) ? () => ref.read(commandSinkProvider).send(ClaimDaily(q.id)) : null,
                    // 보상 = 젬 그림 + 숫자 (layout-v2-brief C2).
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PixelSprite(UiSprites.gem, dots: 8, frames: 3),
                        const SizedBox(width: 4),
                        Text(l10n.uiQuestClaimGems(ref.watch(tablesProvider).meta.dailyQuestRewardGems)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
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
