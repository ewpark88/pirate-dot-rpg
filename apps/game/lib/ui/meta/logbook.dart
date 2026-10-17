import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/scene/scene_vm.dart' show secClock;
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 항해 기록 (S1 2026-10-18): 항해 탭 칭호 띠의 업적 옆 작은 책 버튼 → 큰 숫자 카드 격자. 값은 세이브에 있는 것만(경제
// achievementValue와 같은 셈) — 최고 콤보·총 플레이 시간·처음 시작한 날은 세이브에 없어 뺐다.

/// 기록 한 칸: 아이콘 · 이름 · 값 글.
typedef LogEntry = ({String key, String icon, String label, String value});

List<LogEntry> logbookEntries(AppLocalizations l, GameState s, GameTables t) {
  String n(String metric) => BigNum.from(achievementValue(s, t, metric) ?? 0).format();
  final rushSec = achievementValue(s, t, 'rushBestSec');
  return [
    (key: 'kills', icon: UiSprites.tabCrew, label: l.uiLogKills, value: n('kills')),
    (key: 'bosses', icon: UiSprites.flag, label: l.uiLogBosses, value: n('bosses')),
    (key: 'bestStage', icon: UiSprites.tabMap, label: l.uiLogBestStage, value: n('bestStage')),
    (key: 'rebirths', icon: UiSprites.rebirth, label: l.uiLogRebirths, value: n('rebirths')),
    (key: 'towerBest', icon: UiSprites.trophy, label: l.uiLogTower, value: n('towerBest')),
    if (rushSec != null) (key: 'rushBest', icon: UiSprites.tailwind, label: l.uiLogRush, value: secClock(l, rushSec)),
    (key: 'collection', icon: UiSprites.book, label: l.uiLogCollection, value: n('collection')),
    (key: 'summons', icon: UiSprites.star, label: l.uiLogSummons, value: n('summons')),
    (key: 'fevers', icon: UiSprites.star, label: l.uiLogFevers, value: n('fevers')),
    (key: 'ultimates', icon: UiSprites.tailwind, label: l.uiLogUltimates, value: n('ultimates')),
    (key: 'bounties', icon: UiSprites.flag, label: l.uiLogBounties, value: n('bounties')),
    (key: 'dungeonSteps', icon: UiSprites.chest, label: l.uiLogDungeon, value: n('dungeonSteps')),
    (key: 'shipLevel', icon: UiSprites.tabShip, label: l.uiLogShip, value: n('shipLevel')),
  ];
}

/// 칭호 띠 옆 작은 책 버튼(48dp 누름 칸).
class LogbookButton extends StatelessWidget {
  const LogbookButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppLocalizations.of(context).uiLogTitle,
    excludeSemantics: true,
    child: GestureDetector(
      key: const Key('logbook.open'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(showPixelSheet<void>(context, maxHeight: 0.85, builder: (_) => const LogbookSheet())),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Skin.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
          ),
          child: const SkinIcon(UiSprites.book, size: 22),
        ),
      ),
    ),
  );
}

class LogbookSheet extends ConsumerWidget {
  const LogbookSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entries = logbookEntries(l, ref.watch(gameStateProvider), ref.watch(tablesProvider));
    return ListView(
      key: const Key('logbook.sheet'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        SubRibbon(l.uiLogTitle),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) {
            final cols = (box.maxWidth / 150).floor().clamp(2, 5);
            final w = (box.maxWidth - 8 * (cols - 1)) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in entries)
                  SizedBox(
                    width: w,
                    child: _Card(entry: e),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('logbook.${entry.key}'),
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    decoration: Skin.inset(radius: Skin.radiusCard),
    child: Column(
      children: [
        Row(
          children: [
            SkinIcon(entry.icon, size: 22),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Skin.text(13, color: Skin.sub),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        OutlineText(entry.value, size: 28, tone: OutlineTone.gold, fit: true),
      ],
    ),
  );
}
