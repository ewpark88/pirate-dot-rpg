import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/guide/once_tip.dart';
import 'package:pirate_dot/ui/scene/tower_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';

/// 요일 이름(1 월 ~ 7 일).
String weekdayName(AppLocalizations l, int weekday) => switch (weekday) {
  1 => l.uiWeekday1,
  2 => l.uiWeekday2,
  3 => l.uiWeekday3,
  4 => l.uiWeekday4,
  5 => l.uiWeekday5,
  6 => l.uiWeekday6,
  _ => l.uiWeekday7,
};

/// 계열 이름(skills.json families nameKey).
String familyLabel(AppLocalizations l, GameTables t, String id) => switch (t.skills.families.where((f) => f.id == id)) {
  final m when m.isNotEmpty => tableText(l, m.first.nameKey),
  _ => id,
};

/// 항해 탭 카드 '요일 던전' (S5 계약 platform-weekday-dungeon, 경제 dungeon.dart): 오늘 요일 · 계열 2개 · 단계 1~10(깬 단계 금빛,
/// 고른 단계 테두리) · 단계 보상 · 출전 임시 교체 안내 + 그 선원 초상 · 도전권 · [n단계 도전] [깬 최고 단계 소탕] · 0장이면 광고.
class DungeonCard extends ConsumerStatefulWidget {
  const DungeonCard({super.key});

  @override
  ConsumerState<DungeonCard> createState() => _DungeonCardState();
}

class _DungeonCardState extends ConsumerState<DungeonCard> {
  /// 고른 단계(null = 열린 가장 높은 단계).
  int? _pick;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tablesProvider);
    final s = ref.watch(gameStateProvider.select((s) => (s.dungeon, s.crews.length, s.bounty?.weekday)));
    final d = s.$1;
    if (d == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final state = ref.read(gameStateProvider);
    final now = ref.watch(clockProvider).now();
    final cfg = t.meta.raw.obj('dungeon');
    final steps = cfg.integer('steps');
    final g = dungeonToday(state, t, now);
    final cleared = d.cleared[g.str('id')] ?? 0;
    final open = math.min(cleared + 1, steps);
    final step = (_pick ?? open).clamp(1, open);
    final crews = dungeonCrews(state, t, g);
    final families = g.strs('families');
    final sink = ref.read(commandSinkProvider);
    return Container(
      key: const Key('dungeon.card'),
      padding: const EdgeInsets.all(10),
      decoration: Skin.inset(radius: Skin.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 처음 열렸을 때 한 번 옥토 한 마디(S1 2026-10-18).
          OnceTip(id: 'tip.dungeon', text: l10n.uiTipDungeon),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.uiDungeonTitle, style: Skin.bold(18)),
                    Text(
                      l10n.uiDungeonToday(weekdayName(l10n, g.integer('weekday'))),
                      style: Skin.text(13, color: Skin.sub),
                    ),
                  ],
                ),
              ),
              SceneTicketPill(key: const Key('dungeon.tickets'), tickets: d.tickets, cap: cfg.integer('maxTickets')),
            ],
          ),
          const SizedBox(height: 4),
          // 오늘의 계열 칩(비면 모든 계열).
          Wrap(
            spacing: 6,
            children: [
              for (final f in families.isEmpty ? [null] : families)
                _Chip(text: f == null ? l10n.uiDungeonAll : familyLabel(l10n, t, f)),
            ],
          ),
          const SizedBox(height: 8),
          // 단계 1~10: 깬 단계 금빛, 열린 단계만 고를 수 있다.
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 1; i <= steps; i++)
                _StepDot(
                  key: Key('dungeon.step.$i'),
                  n: i,
                  cleared: i <= cleared,
                  picked: i == step,
                  onTap: i <= open ? () => setState(() => _pick = i) : null,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.uiDungeonReward(step * cfg.integer('cardsPerStep'), step * cfg.integer('gemsPerStep')),
            key: const Key('dungeon.reward'),
            style: Skin.text(13, color: Skin.mintInk),
          ),
          const SizedBox(height: 6),
          // 출전 임시 교체 안내 + 그 선원.
          if (crews.isEmpty)
            Text(
              l10n.uiDungeonNoCrew,
              key: const Key('dungeon.noCrew'),
              style: Skin.text(13, color: Skin.danger),
            )
          else ...[
            Text(l10n.uiDungeonCrewNote, style: Skin.text(12, color: Skin.sub)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [for (final id in crews) CrewPortrait(crew: t.crews.byId(id), size: 36)],
            ),
          ],
          const SizedBox(height: 8),
          if (d.tickets == 0)
            const SceneNoTicketRow(placement: AdPlacement.dungeonTicket, adKey: Key('dungeon.ad'))
          else
            Row(
              children: [
                Expanded(
                  child: SkinButton(
                    key: const Key('dungeon.start'),
                    onPressed: canStartDungeon(state, t, now, step) ? () => sink.send(StartDungeon(step)) : null,
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiDungeonStart(step))),
                  ),
                ),
                if (cleared > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkinButton(
                      key: const Key('dungeon.sweep'),
                      tone: SkinTone.gold,
                      onPressed: () => sink.send(SweepDungeon(cleared)),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiDungeonSweep(cleared))),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Skin.cream,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Skin.outline.withValues(alpha: 0.3), width: 1.5),
    ),
    child: Text(text, style: Skin.text(12, color: Skin.goldInk)),
  );
}

/// 단계 동그라미(36dp, 누름 44dp): 깬 단계 금빛 · 고른 단계 굵은 테두리 · 안 열린 단계 흐림.
class _StepDot extends StatelessWidget {
  const _StepDot({required this.n, required this.cleared, required this.picked, this.onTap, super.key});

  final int n;
  final bool cleared;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox.square(
      dimension: 44,
      child: Center(
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cleared ? const Color(0xFFFFD84A) : Skin.cream,
              border: Border.all(color: picked ? Skin.danger : Skin.outline, width: picked ? 3 : 2),
            ),
            child: Text(n.toString(), style: Skin.bold(14, color: Skin.goldInk)),
          ),
        ),
      ),
    ),
  );
}
