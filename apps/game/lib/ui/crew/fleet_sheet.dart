import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_filter.dart';
import 'package:pirate_dot/ui/crew/crew_filter_bar.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/crew/swap_compare.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/build_counter.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// [slot] 칸 후보 시트: 쉬는 선원 먼저(파워순), 출전 중은 뒤(고르면 두 칸이 자리를 바꾼다). 찬 칸은 ‘칸 비우기’도.
Future<void> showFleetPicker(BuildContext context, int slot) =>
    showPixelSheet<void>(context, builder: (_) => _FleetPicker(slot: slot));

/// 선원 상세의 ‘출전’: 빈 칸이 있으면 바로 앉히고, 가득이면 바꿀 선원을 고른다.
Future<void> deployCrew(BuildContext context, WidgetRef ref, String crewId) async {
  final slots = ref.read(fleetSlotsProvider);
  final empty = slots.indexOf(null);
  if (empty >= 0) {
    ref.read(fleetCommandsProvider).setSlot(empty, crewId);
    return;
  }
  await showPixelSheet<void>(context, builder: (_) => _SwapPicker(crewId: crewId));
}

/// 지금 출전 중인 선원 수.
int deployedCount(WidgetRef ref) => ref.read(fleetSlotsProvider).whereType<String>().length;

/// 선원 상세의 ‘내리기’ (사용자 버그 2026-10-16 '출전 선원이 3 → 1 → 0'): 마지막 한 명은 못 빼고,
/// 내리면 4초 동안 '되돌리기'가 붙은 안내를 띄운다(바꾸기·닫기 옆이라 잘못 누르기 쉽다).
void undeployCrew(BuildContext context, WidgetRef ref, String crewId) {
  final l10n = AppLocalizations.of(context);
  final slot = ref.read(fleetSlotsProvider).indexOf(crewId);
  if (slot < 0) return;
  if (deployedCount(ref) <= 1) {
    showSkinToast(context, l10n.uiFleetKeepOne);
    return;
  }
  final fleet = ref.read(fleetCommandsProvider)..setSlot(slot, null);
  final name = shortCrewName(l10n, ref.read(tablesProvider).crews.byId(crewId));
  showSkinToast(context, l10n.uiFleetRemoved(name), action: l10n.uiUndo, onAction: () => fleet.setSlot(slot, crewId));
}

class _FleetPicker extends ConsumerWidget {
  const _FleetPicker({required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    countBuild('fleetPicker');
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final slots = ref.watch(fleetSlotsProvider);
    // 레벨이 바뀔 때만(문자열 ==) — Map은 ==가 없어 틱마다 다시 짓게 된다(사용자 버그 2026-10-16 버벅임).
    ref.watch(gameStateProvider.select((s) => [for (final e in s.crews.entries) '${e.key}${e.value.level}'].join()));
    final levels = {for (final e in ref.read(gameStateProvider).crews.entries) e.key: e.value.level};
    // 도감과 같은 정렬·필터(보유만). 기본(번호순)일 땐 파워순. 쉬는 선원 먼저, 출전 중은 뒤(고르면 자리만 바뀐다 — 사용자 버그 2026-10-15).
    final q = ref.watch(crewQueryProvider);
    int power(CrewDef c) => (crewPowerOf(tables, levels[c.id]!) * 1000).round();
    final queried = queryCrews(
      ref.read(gameStateProvider),
      tables,
      q.copyWith(owned: OwnedFilter.owned, upOnly: false),
    );
    if (q.sort == CrewSort.number) queried.sort((a, b) => power(b) - power(a));
    final owned = [
      ...queried.where((c) => !slots.contains(c.id)),
      ...queried.where((c) => slots.contains(c.id)),
    ];
    Future<void> pick(String? id) async {
      final swap = id != null && slots.contains(id) && slots.indexOf(id) != slot;
      // 찬 칸을 쉬는 선원으로 바꿀 때는 먼저 비교 창(사용자 피드백 #34) — 취소면 그대로.
      final current = slot < slots.length ? slots[slot] : null;
      if (id != null && current != null && current != id && !slots.contains(id)) {
        if (!await showSwapCompare(context, current, id) || !context.mounted) return;
      }
      ref.read(fleetCommandsProvider).setSlot(slot, id);
      Navigator.of(context).pop();
      if (swap) showSkinToast(context, l10n.uiFleetSwapped);
    }

    return ListView(
      key: Key('fleet.picker.$slot'),
      padding: const EdgeInsets.all(8),
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.uiFleetSlotTitle(slot + 1), style: Theme.of(context).textTheme.titleMedium)),
            // 마지막 출전 선원은 비울 수 없다.
            if (slot < slots.length && slots[slot] != null && slots.whereType<String>().length > 1)
              PixelButton(key: const Key('fleet.clear'), onPressed: () => pick(null), child: Text(l10n.uiFleetClear)),
          ],
        ),
        const SizedBox(height: 6),
        const CrewQueryBar(picker: true),
        const SizedBox(height: 4),
        if (owned.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(l10n.uiFilterEmpty, key: const Key('fleet.pick.empty'))),
          ),
        for (final c in owned)
          _CrewRow(
            def: c,
            level: levels[c.id]!,
            deployed: slots.contains(c.id),
            onTap: () => pick(c.id),
            key: Key('fleet.pick.${c.id}'),
          ),
      ],
    );
  }
}

class _SwapPicker extends ConsumerWidget {
  const _SwapPicker({required this.crewId});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final slots = ref.watch(fleetSlotsProvider);
    // 레벨이 바뀔 때만(문자열 ==) — Map은 ==가 없어 틱마다 다시 짓게 된다(사용자 버그 2026-10-16 버벅임).
    ref.watch(gameStateProvider.select((s) => [for (final e in s.crews.entries) '${e.key}${e.value.level}'].join()));
    final levels = {for (final e in ref.read(gameStateProvider).crews.entries) e.key: e.value.level};
    return ListView(
      key: const Key('fleet.swap'),
      padding: const EdgeInsets.all(8),
      children: [
        Text(l10n.uiFleetSwapTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (i, id) in slots.indexed)
          if (id != null)
            _CrewRow(
              def: tables.crews.byId(id),
              level: levels[id] ?? 1,
              deployed: true,
              onTap: () async {
                // 이 칸 선원 → 새 선원 비교(#34) — 취소면 그대로.
                if (!await showSwapCompare(context, id, crewId) || !context.mounted) return;
                ref.read(fleetCommandsProvider).setSlot(i, crewId);
                Navigator.of(context).pop();
              },
              key: Key('fleet.swap.$id'),
            ),
      ],
    );
  }
}

/// 후보 한 줄: 초상 · 짧은 이름 · 등급 색 레벨 · 계열 · 출전 중 표시.
class _CrewRow extends ConsumerWidget {
  const _CrewRow({required this.def, required this.level, required this.deployed, required this.onTap, super.key});

  final CrewDef def;
  final int level;
  final bool deployed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final rarity = rarityOfLevel(tables.rarities, level);
    final dim = TextStyle(color: PixelPalette.textDim, fontSize: Theme.of(context).textTheme.labelSmall?.fontSize);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTap),
          child: Row(
            children: [
              // PB 얼굴 초상, 등급 색 둥근 테두리.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: rarityColor(rarity), width: 3),
                  color: Skin.cream,
                ),
                // 신화는 금 안쪽 선 (빨강 + 금).
                foregroundDecoration: rarityInnerGold(rarity)
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: mythicGold, width: 1.5),
                      )
                    : null,
                child: ClipOval(child: Image.asset(pbPortrait(def.id), fit: BoxFit.cover)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortCrewName(l10n, def)),
                    Text(
                      '${l10n.uiLevel(level)} · ${tableText(l10n, tables.skills.byId(def.family).nameKey)}',
                      style: dim,
                    ),
                    // 특색 아이콘 4개(개성 v2) — 고를 때 성향이 보이게. 다음 보스에게 잘 먹히는 계열이면 '보스 약점' 칩(#25).
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CrewIdentityIcons(crewId: def.id, size: 12),
                        if (ref.watch(bossCounterFamiliesProvider).contains(def.family))
                          CounterChip(key: Key('fleet.counter.${def.id}')),
                      ],
                    ),
                  ],
                ),
              ),
              // 이 선원 혼자의 초당 공격력(경제 fleetDps — 상세와 같은 값).
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    // 줄이 다시 지어질 때(레벨이 바뀔 때)만 계산 — 틱마다 40명 계산하지 않는다.
                    fleetDps(ref.read(gameStateProvider), tables, [def.id]).format(),
                    key: Key('fleet.dps.${def.id}'),
                    style: Skin.text(15, color: Skin.goldInk),
                  ),
                  if (deployed) Text(l10n.uiCrewDeployed, style: const TextStyle(color: PixelPalette.accent)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선원 줄 칸을 눌렀을 때 시트를 연다 (BattleButtons에서).
void openFleetPicker(BuildContext context, int slot) => unawaited(showFleetPicker(context, slot));

/// 선원 상세의 ‘바꾸기’: 이 선원이 앉은 칸의 후보 시트를 연다.
Future<void> replaceCrew(BuildContext context, WidgetRef ref, String crewId) async {
  final slot = ref.read(fleetSlotsProvider).indexOf(crewId);
  if (slot >= 0) await showFleetPicker(context, slot);
}
