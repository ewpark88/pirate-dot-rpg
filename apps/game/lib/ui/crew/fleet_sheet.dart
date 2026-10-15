import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
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

/// 선원 상세의 ‘내리기’.
void undeployCrew(WidgetRef ref, String crewId) {
  final slot = ref.read(fleetSlotsProvider).indexOf(crewId);
  if (slot >= 0) ref.read(fleetCommandsProvider).setSlot(slot, null);
}

class _FleetPicker extends ConsumerWidget {
  const _FleetPicker({required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final slots = ref.watch(fleetSlotsProvider);
    final levels = ref.watch(gameStateProvider.select((s) => {for (final e in s.crews.entries) e.key: e.value.level}));
    // 쉬는 선원을 먼저(파워순), 출전 중인 선원은 뒤에 (출전 중을 고르면 자리만 바뀐다 — 사용자 버그 2026-10-15).
    int power(CrewDef c) => (crewPowerOf(tables, levels[c.id]!) * 1000).round();
    final owned =
        [
          for (final c in tables.crews.crews)
            if (levels.containsKey(c.id)) c,
        ]..sort((a, b) {
          final da = slots.contains(a.id) ? 1 : 0;
          final db = slots.contains(b.id) ? 1 : 0;
          return da != db ? da - db : power(b) - power(a);
        });
    void pick(String? id) {
      final swap = id != null && slots.contains(id) && slots.indexOf(id) != slot;
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
            if (slot < slots.length && slots[slot] != null)
              PixelButton(key: const Key('fleet.clear'), onPressed: () => pick(null), child: Text(l10n.uiFleetClear)),
          ],
        ),
        const SizedBox(height: 8),
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
    final levels = ref.watch(gameStateProvider.select((s) => {for (final e in s.crews.entries) e.key: e.value.level}));
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
              onTap: () {
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
                  ],
                ),
              ),
              if (deployed) Text(l10n.uiCrewDeployed, style: const TextStyle(color: PixelPalette.accent)),
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
