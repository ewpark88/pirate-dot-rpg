import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show BossPortrait;
import 'package:pirate_dot/ui/guide/once_tip.dart';
import 'package:pirate_dot/ui/scene/scene_vm.dart';
import 'package:pirate_dot/ui/scene/tower_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 항해 탭 카드 '보스 러시' (S5 계약, platform-boss-rush): 이번 주 보스 5 초상(마지막 대보스는 크게) · 최고 기록 ·
/// 기록 구간(받은 구간은 금빛) · 도전 n · [도전] · 0이면 [광고로 1번]. 탑과 같이 열린다.
class RushCard extends ConsumerWidget {
  const RushCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tablesProvider);
    final r = ref.watch(gameStateProvider.select((s) => s.rush));
    final can = ref.watch(gameStateProvider.select((s) => canStartRush(s, t)));
    if (r == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final cfg = t.meta.raw.obj('rush');
    final bosses = rushBosses(t, r.week ?? rushWeek(ref.watch(clockProvider).now()));
    final brackets = cfg.objs('brackets');
    final best = r.bestTicks;
    return Container(
      key: const Key('rush.card'),
      padding: const EdgeInsets.all(10),
      decoration: Skin.inset(radius: Skin.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 처음 열렸을 때 한 번 옥토 한 마디(S1 2026-10-18).
          OnceTip(id: 'tip.rush', text: l10n.uiTipRush),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.uiRushTitle, style: Skin.bold(18)),
                    Text(
                      best == null ? l10n.uiRushWeek : l10n.uiRushBest(sceneClock(l10n, best, t.waves.tickMs)),
                      key: const Key('rush.best'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Skin.text(13, color: Skin.sub),
                    ),
                  ],
                ),
              ),
              SceneTicketPill(key: const Key('rush.tickets'), tickets: r.tickets, cap: cfg.integer('weeklyTickets')),
            ],
          ),
          const SizedBox(height: 6),
          // 이번 주 보스 차례 — 마지막(대보스)은 크게.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, id) in bosses.indexed)
                Expanded(
                  flex: i == bosses.length - 1 ? 4 : 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (_, box) => BossPortrait(key: Key('rush.boss.$i'), bossId: id, size: box.maxWidth),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 기록 구간: 'm:ss 안 · 젬 n(· 조각 n)' — 이번 주 받은 구간은 금빛.
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final (i, b) in brackets.indexed)
                _BracketChip(
                  key: Key('rush.bracket.$i'),
                  done: r.claimed.contains(i),
                  text: [
                    l10n.uiRushBracket(secClock(l10n, b.number('sec'))),
                    sceneReward(l10n, gems: b.integer('gems'), pieces: b.intOrNull('pieces') ?? 0),
                  ].join(l10n.uiListSep),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (r.tickets == 0)
            const SceneNoTicketRow(placement: AdPlacement.rushTicket, adKey: Key('rush.ad'))
          else
            SkinButton(
              key: const Key('rush.start'),
              onPressed: can ? () => ref.read(commandSinkProvider).send(const StartRush()) : null,
              child: Text(l10n.uiSceneChallenge),
            ),
        ],
      ),
    );
  }
}

class _BracketChip extends StatelessWidget {
  const _BracketChip({required this.done, required this.text, super.key});

  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: done ? const Color(0xFFFFE27A) : Skin.cream,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: done ? Skin.goldBottom : Skin.outline.withValues(alpha: 0.3), width: 1.5),
    ),
    child: Text(text, style: Skin.text(12, color: done ? Skin.goldInk : Skin.sub)),
  );
}
