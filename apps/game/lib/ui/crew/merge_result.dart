import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/rolling_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';

// 일괄 합치기 결과 (사용자 2026-10-18 '어떤 캐릭터가 합쳐졌는지 팝업으로 · 연출도 · 얼마나 세졌는지'): 엔진은 합치기에 이벤트가
// 없어(저장 이유만) 누르기 전 상태와 뒤 상태를 비교한다. 위: 초상들이 차례로(0.15초) 들어와 가운데로 모여 '쾅' · 아래: 선원마다
// Lv 굴림 · 공격력 전→후(초록 +%) · 등급이 오르면 '희귀 → 영웅' · 맨 아래 함대 전투력 전→후. 많으면 상위 6 + '외 n명'. 탭하면 끝.

/// 한 선원의 합치기 전후.
typedef MergeChange = ({
  String id,
  int fromLevel,
  int toLevel,
  BigNum fromDps,
  BigNum toDps,
  String? fromRarity,
  String? toRarity,
});

/// 두 상태 사이에 레벨이 오른 선원(공격력 증가 큰 순).
List<MergeChange> mergeChanges(GameState before, GameState after, GameTables t) {
  final out = <MergeChange>[];
  for (final e in after.crews.entries) {
    final was = before.crews[e.key];
    if (was == null || e.value.level <= was.level) continue;
    final r0 = rarityOfLevel(t.rarities, was.level).id;
    final r1 = rarityOfLevel(t.rarities, e.value.level).id;
    out.add((
      id: e.key,
      fromLevel: was.level,
      toLevel: e.value.level,
      fromDps: fleetDps(before, t, [e.key]),
      toDps: fleetDps(after, t, [e.key]),
      fromRarity: r0 == r1 ? null : r0,
      toRarity: r0 == r1 ? null : r1,
    ));
  }
  out.sort((a, b) => (b.toDps - b.fromDps).compareTo(a.toDps - a.fromDps));
  return out;
}

/// 일괄 합치기를 보내고, 다음 상태에서 바뀐 선원이 있으면 결과 창.
void mergeAllWithResult(BuildContext context, WidgetRef ref) {
  final t = ref.read(tablesProvider);
  final before = ref.read(gameStateProvider);
  ref.read(commandSinkProvider).send(const MergeAllCards());
  unawaited(
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!context.mounted) return;
      final after = ref.read(gameStateProvider);
      final changes = mergeChanges(before, after, t);
      if (changes.isEmpty) return;
      unawaited(
        showSkinDialog<void>(
          context,
          builder: (_) => MergeResultDialog(
            changes: changes,
            fleetBefore: fleetDps(before, t, activeFleet(before, t)),
            fleetAfter: fleetDps(after, t, activeFleet(after, t)),
          ),
        ),
      );
    }),
  );
}

String rarityName(AppLocalizations l, GameTables t, String id) =>
    tableText(l, t.rarities.rarities.firstWhere((r) => r.id == id).nameKey);

class MergeResultDialog extends ConsumerStatefulWidget {
  const MergeResultDialog({required this.changes, required this.fleetBefore, required this.fleetAfter, super.key});

  final List<MergeChange> changes;
  final BigNum fleetBefore;
  final BigNum fleetAfter;

  @override
  ConsumerState<MergeResultDialog> createState() => _MergeResultDialogState();
}

class _MergeResultDialogState extends ConsumerState<MergeResultDialog> with SingleTickerProviderStateMixin {
  static const _show = 6;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 600 + 150 * math.min(widget.changes.length, _show)),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_c.forward());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    if (MediaQuery.disableAnimationsOf(context)) _c.value = 1;
    final shown = widget.changes.take(_show).toList();
    final more = widget.changes.length - shown.length;
    return GestureDetector(
      // 탭하면 연출을 끝까지 넘긴다.
      onTap: () => _c.value = 1,
      child: PixelDialog(
        key: const Key('merge.result'),
        title: l10n.uiMergeResultTitle,
        content: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final total = _c.duration!.inMilliseconds;
            // 0 ~ 0.15×n: 초상이 차례로 들어옴, 그 뒤 0.35초: 가운데로 모여 '쾅', 그 뒤 줄 공개.
            final inEnd = 150 * shown.length / total;
            final gather = ((_c.value - inEnd) / (350 / total)).clamp(0.0, 1.0);
            final rows = ((_c.value - inEnd - 350 / total) / (250 / total)).clamp(0.0, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 76,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final mid = box.maxWidth / 2;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final (i, c) in shown.indexed)
                            () {
                              final appear = ((_c.value * total - 150 * i) / 150).clamp(0.0, 1.0);
                              final spread = (i - (shown.length - 1) / 2) * 52.0;
                              final x = mid + spread * (1 - Curves.easeIn.transform(gather)) - 26;
                              return Positioned(
                                left: x,
                                top: 12 - 24 * (1 - Curves.easeOutBack.transform(appear)),
                                child: Opacity(
                                  opacity: appear,
                                  child: CrewPortrait(crew: t.crews.byId(c.id), size: 52),
                                ),
                              );
                            }(),
                          // '쾅' 빛 고리(모인 순간).
                          if (gather >= 1 && rows < 1)
                            Positioned(
                              left: mid - 40 - 30 * rows,
                              top: 38 - 40 - 30 * rows,
                              child: Container(
                                key: const Key('merge.burst'),
                                width: 80 + 60 * rows,
                                height: 80 + 60 * rows,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFD84A).withValues(alpha: 1 - rows),
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: rows,
                  child: Column(
                    children: [
                      for (final c in shown) _Row(change: c, t: t, ready: rows >= 1),
                      if (more > 0) Text(l10n.uiMergeMore(more), style: Skin.text(13, color: Skin.sub)),
                      const SizedBox(height: 6),
                      OutlineText(
                        l10n.uiMergeFleet(widget.fleetBefore.format(), widget.fleetAfter.format()),
                        key: const Key('merge.fleet'),
                        size: 15,
                        tone: OutlineTone.gold,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.change, required this.t, required this.ready});

  final MergeChange change;
  final GameTables t;

  /// 줄이 다 보였으면 Lv를 새 값으로 굴린다.
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = change;
    final gain = c.fromDps.isZero ? 0 : ((c.toDps.toDouble() / c.fromDps.toDouble() - 1) * 100).round();
    return Padding(
      key: Key('merge.row.${c.id}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          CrewPortrait(crew: t.crews.byId(c.id), size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tableText(l10n, t.crews.byId(c.id).nameKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Skin.bold(14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: RollingText(
                          l10n.uiMergeLv(c.fromLevel, ready ? c.toLevel : c.fromLevel),
                          style: Skin.bold(13, color: Skin.goldInk),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.uiMergeAtk(c.fromDps.format(), c.toDps.format()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Skin.text(12, color: Skin.sub),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (gain > 0) Text(l10n.uiMergeGain(gain), style: Skin.bold(12, color: Skin.mintInk)),
                  ],
                ),
              ],
            ),
          ),
          if (c.toRarity != null)
            Container(
              key: Key('merge.rarity.${c.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFFE27A), borderRadius: BorderRadius.circular(8)),
              child: Text(
                l10n.uiMergeRarity(rarityName(l10n, t, c.fromRarity!), rarityName(l10n, t, c.toRarity!)),
                style: Skin.bold(11, color: Skin.goldInk),
              ),
            ),
        ],
      ),
    );
  }
}
