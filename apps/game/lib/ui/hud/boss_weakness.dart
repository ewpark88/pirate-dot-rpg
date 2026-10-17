import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 보스전 약점 표시 (설계서 4.11): 보스 이름 + ‘약점’ + 잘 먹히는 계열 칩. 보는 것만 — 편성은 자동이다.
/// 약점이 없는 보스·보스전이 아닐 때는 아무것도 그리지 않는다.
class BossWeakness extends ConsumerWidget {
  const BossWeakness({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    // 지금 보스 = 전장의 보스 적의 kind (regions.json bosses id).
    final bossId = ref.watch(
      gameStateProvider.select((s) {
        final b = s.battle;
        if (b == null || !b.bossActive) return null;
        for (final e in b.enemies) {
          if (e.boss) return e.kind;
        }
        return null;
      }),
    );
    final boss = bossId == null ? null : tables.regions.bosses[bossId];
    if (boss == null || (bossCounters(boss).isEmpty && boss.traits.isEmpty)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.labelSmall?.copyWith(color: Skin.ink);

    // 왼쪽 위 작은 알약 하나(사용자 피드백 #9 C — 전폭 띠 대신, 보스 이름은 등장 이름표가 보여 준다). 누름 통과.
    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const Key('boss.weak'),
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xEEFFF0F2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: Skin.shadowSmall,
          ),
          child: Semantics(
            label: tableText(l10n, boss.nameKey),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 보스 특성(#25) + 약점 = 표 약점 ∪ 특성 카운터.
                for (final t in boss.traits)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(traitIcon(t.type), size: 14, color: Skin.ink),
                      const SizedBox(width: 2),
                      Text(traitName(l10n, t), style: small),
                    ],
                  ),
                if (bossCounters(boss).isNotEmpty) WeakChips(boss: boss, labelStyle: small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ‘약점’ + 계열 칩들 (보스전 HUD와 항해 탭 해역 보스 미리보기가 같이 쓴다).
class WeakChips extends ConsumerWidget {
  const WeakChips({required this.boss, this.labelStyle, super.key});

  final BossDef boss;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    // 특성 카운터까지 합치면 칩이 많다 — 좁으면 다음 줄로.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        Text(l10n.uiBossWeak, style: labelStyle),
        // 약점 = 표의 약점 + 특성 카운터 계열 (#25).
        for (final f in bossCounters(boss)) ...[
          const SizedBox(width: 4),
          // 약점 칩: 도트 프레임 (누르는 것 아님).
          PixelFrame(
            key: Key('boss.weak.$f'),
            padding: 2,
            highlight: null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(tableText(l10n, tables.skills.byId(f).nameKey), style: labelStyle),
            ),
          ),
        ],
      ],
    );
  }
}
