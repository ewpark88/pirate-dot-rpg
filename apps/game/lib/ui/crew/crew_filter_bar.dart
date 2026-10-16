import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_filter.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 도감 정렬·필터 화면 조각 (조건·계산은 crew_filter.dart).

/// 격자 위 한 줄: [정렬 ▼] [보유 전체/보유/미보유] [필터 n].
class CrewQueryBar extends ConsumerWidget {
  const CrewQueryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final q = ref.watch(crewQueryProvider);
    final set = ref.read(crewQueryProvider.notifier).set;
    String sortText(CrewSort v) => switch (v) {
      CrewSort.number => l10n.uiSortNum,
      CrewSort.rarity => l10n.uiSortRarity,
      CrewSort.dps => l10n.uiSortDps,
    };
    String ownedText(OwnedFilter v) => switch (v) {
      OwnedFilter.all => l10n.uiFilterAll,
      OwnedFilter.owned => l10n.uiFilterOwned,
      OwnedFilter.unowned => l10n.uiFilterUnowned,
    };
    final t = ref.watch(tablesProvider);
    final up = ref.watch(gameStateProvider.select((s) => levelUpIds(s, t).length));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 합치기 가능 n명 → 그 선원만 보기 (다시 누르면 모두). 위 '일괄 합치기'로 한 번에 합친다.
        if (up > 0 || q.upOnly)
          _Chip(
            key: const Key('crew.upOnly'),
            icon: Icons.arrow_circle_up_rounded,
            label: q.upOnly ? l10n.uiCrewUpShowAll : l10n.uiCrewUpCount(up),
            on: q.upOnly,
            color: Skin.mintInk,
            onTap: () => set(q.copyWith(upOnly: !q.upOnly)),
          ),
        _Chip(
          key: const Key('crew.sort'),
          icon: Icons.sort_rounded,
          label: sortText(q.sort),
          on: q.sort != CrewSort.number,
          // 누를 때마다 다음 정렬.
          onTap: () => set(q.copyWith(sort: CrewSort.values[(q.sort.index + 1) % CrewSort.values.length])),
        ),
        _Chip(
          key: const Key('crew.owned'),
          icon: Icons.inventory_rounded,
          label: ownedText(q.owned),
          on: q.owned != OwnedFilter.all,
          onTap: () => set(q.copyWith(owned: OwnedFilter.values[(q.owned.index + 1) % OwnedFilter.values.length])),
        ),
        _Chip(
          key: const Key('crew.filter'),
          icon: Icons.tune_rounded,
          label: q.traitCount == 0 ? l10n.uiFilter : l10n.uiFilterCount(q.traitCount),
          on: q.traitCount > 0,
          onTap: () => unawaited(
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: const RoundedRectangleBorder(),
              builder: (_) => const CrewFilterSheet(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
    this.color,
    super.key,
  });

  /// 글·아이콘 색 (기본 잉크·켜지면 파랑).
  final Color? color;
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // 누르는 영역 48dp(그림 40dp + 위아래 4dp).
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: on ? Skin.skyDeep : Skin.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? Skin.primaryBottom : Skin.cardEdge, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color ?? (on ? Skin.primaryEdge : Skin.ink)),
              const SizedBox(width: 4),
              Text(label, style: Skin.text(14, color: color ?? (on ? Skin.primaryEdge : Skin.ink))),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 특성 필터 시트: 계열 · 조준 · 범위 · 명중 (같은 칸을 다시 누르면 끔) + 초기화.
class CrewFilterSheet extends ConsumerWidget {
  const CrewFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final q = ref.watch(crewQueryProvider);
    final set = ref.read(crewQueryProvider.notifier).set;
    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Skin.text(14, color: Skin.sub)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );
    Widget chip(String key, String label, {required bool on, required VoidCallback onTap, IconData? icon}) =>
        _Chip(key: Key('crew.filter.$key'), icon: icon ?? Icons.circle_outlined, label: label, on: on, onTap: onTap);
    return SafeArea(
      child: Container(
        key: const Key('crew.filterSheet'),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        decoration: BoxDecoration(color: Skin.card, borderRadius: BorderRadius.circular(18), boxShadow: Skin.shadow),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.uiFilter, style: Skin.text(18))),
                  TextButton(
                    key: const Key('crew.filter.reset'),
                    onPressed: () => ref.read(crewQueryProvider.notifier).reset(),
                    child: Text(l10n.uiFilterReset),
                  ),
                ],
              ),
              group(l10n.uiFilterFamily, [
                for (final f in t.skills.families)
                  chip(
                    'family.${f.id}',
                    tableText(l10n, f.nameKey),
                    on: q.family == f.id,
                    onTap: () => set(q.copyWith(family: () => q.family == f.id ? null : f.id)),
                  ),
              ]),
              group(l10n.uiIdAim, [
                for (final a in AimKind.values)
                  chip(
                    'aim.${a.name}',
                    aimText(l10n, a),
                    icon: aimIcon(a),
                    on: q.aim == a,
                    onTap: () => set(q.copyWith(aim: () => q.aim == a ? null : a)),
                  ),
              ]),
              group(l10n.uiIdArea, [
                for (final v in [true, false])
                  chip(
                    'area.$v',
                    v ? l10n.uiAreaWide : l10n.uiAreaSingle,
                    icon: v ? Icons.blur_circular_rounded : Icons.fiber_manual_record_rounded,
                    on: q.area == v,
                    onTap: () => set(q.copyWith(area: () => q.area == v ? null : v)),
                  ),
              ]),
              group(l10n.uiIdHit, [
                for (final h in HitKind.values)
                  chip(
                    'hit.${h.name}',
                    hitText(l10n, h),
                    icon: h == HitKind.free ? Icons.redo_rounded : Icons.arrow_forward_rounded,
                    on: q.hit == h,
                    onTap: () => set(q.copyWith(hit: () => q.hit == h ? null : h)),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
