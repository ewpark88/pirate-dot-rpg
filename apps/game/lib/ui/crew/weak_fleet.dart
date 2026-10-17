import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show BossPortrait, bossName;
import 'package:pirate_dot/ui/hud/boss_traits.dart' show bossCounters;
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 약점 편성 (S1 2026-10-18): 편성 화면 위 '다음 보스' 칸(초상·약점 계열 칩·[약점 편성]) · 약점 계열 선원 카드에 '약점!' 금빛 배지 ·
// 보스 실패 안내에서도 바로. 엔진 AutoFleet엔 우선 계열 인자가 없어 UI가 고르고 SetFleetSlot으로 칸마다 보낸다(계열 상한은 지킨다).

/// 다음(또는 지금 싸우는) 보스 — 경제 bossPreview.
final nextBossProvider = Provider<BossDef>((ref) {
  final t = ref.watch(tablesProvider);
  final id = ref.watch(gameStateProvider.select((s) => bossPreview(s, t).bossId));
  return t.regions.bosses[id]!;
});

/// 다음 보스에 잘 먹히는 계열(약점 + 특성 카운터).
final weakFamiliesProvider = Provider<Set<String>>((ref) => bossCounters(ref.watch(nextBossProvider)).toSet());

/// 약점 계열 먼저(그 안에선 파워순), 나머지는 파워순 — 같은 계열은 상한까지, [slots]명.
List<String> weakFleet(GameState s, GameTables t, int slots, Set<String> weak) {
  final owned = [
    for (final c in t.crews.crews)
      if (s.crews[c.id] case final st?) (def: c, power: crewPowerOf(t, st.level), weak: weak.contains(c.family)),
  ]..sort((a, b) => a.weak != b.weak ? (a.weak ? -1 : 1) : b.power.compareTo(a.power));
  final perFamily = <String, int>{};
  final out = <String>[];
  for (final c in owned) {
    if (out.length >= slots) break;
    final n = perFamily[c.def.family] ?? 0;
    if (n >= t.skills.maxSameFamilyInFleet) continue;
    perFamily[c.def.family] = n + 1;
    out.add(c.def.id);
  }
  return out;
}

/// [약점 편성]: 칸마다 SetFleetSlot(앞 칸부터 — 다른 칸에 있던 선원은 자리를 바꾼다). 이미 그 편성이면 토스트.
void weakFleetWithFeedback(BuildContext context, WidgetRef ref) {
  final t = ref.read(tablesProvider);
  final s = ref.read(gameStateProvider);
  final slots = ref.read(fleetSlotsProvider);
  final target = weakFleet(s, t, slots.length, ref.read(weakFamiliesProvider));
  final l10n = AppLocalizations.of(context);
  if ([for (var i = 0; i < target.length; i++) slots[i] == target[i]].every((same) => same)) {
    showSkinToast(context, l10n.uiWeakFleetSame);
    return;
  }
  final fleet = ref.read(fleetCommandsProvider);
  for (final (i, id) in target.indexed) {
    if (slots[i] != id) fleet.setSlot(i, id);
  }
  unawaited(
    Future<void>.delayed(Duration.zero, () => context.mounted ? showSkinToast(context, l10n.uiWeakFleetDone) : null),
  );
}

/// 편성 화면 위 '다음 보스' 칸.
class NextBossStrip extends ConsumerWidget {
  const NextBossStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boss = ref.watch(nextBossProvider);
    final weak = bossCounters(boss).isNotEmpty;
    return Container(
      key: const Key('fleet.nextBoss'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: Skin.inset(radius: Skin.radiusCard),
      child: Row(
        children: [
          BossPortrait(bossId: boss.id, size: 52),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.uiNextBoss(bossName(l10n, ref, boss.id)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Skin.bold(14),
                ),
                if (weak)
                  WeakChips(
                    boss: boss,
                    labelStyle: Skin.text(12, color: Skin.sub),
                  ),
              ],
            ),
          ),
          if (weak) ...[
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 104),
              child: SkinButton(
                key: const Key('fleet.weak'),
                tone: SkinTone.gold,
                height: 44,
                onPressed: () => weakFleetWithFeedback(context, ref),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiWeakFleet)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 선원 카드 '약점!' 금빛 배지(다음 보스 약점 계열이고 보유했을 때).
class WeakBadge extends StatelessWidget {
  const WeakBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Skin.goldTop, Skin.goldBottom],
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Skin.outline, width: 2),
      boxShadow: [BoxShadow(color: Skin.goldTop.withValues(alpha: 0.7), blurRadius: 6)],
    ),
    child: Text(AppLocalizations.of(context).uiWeakBadge, style: Skin.bold(11, color: Skin.goldInk)),
  );
}
