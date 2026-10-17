import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 출전 칸이 새로 열리면(처음 · 환생 뒤 다시 열림) 빈 칸에 쉬는 선원 중 가장 센(레벨 높은) 선원을 넣는다
/// (S1 실기기 2026-10-18 '열린 4번째 칸이 비어 있다'). 사용자가 직접 비운 칸은 건드리지 않는다 — 칸 수가 늘 때만.
class FleetAutoFill extends ConsumerStatefulWidget {
  const FleetAutoFill({super.key});

  @override
  ConsumerState<FleetAutoFill> createState() => _FleetAutoFillState();
}

class _FleetAutoFillState extends ConsumerState<FleetAutoFill> {
  @override
  void initState() {
    super.initState();
    final t = ref.read(tablesProvider);
    ref.listenManual(gameStateProvider.select((s) => fleetSlots(s, t)), (was, now) {
      if (was == null || now <= was) return;
      final s = ref.read(gameStateProvider);
      final active = activeFleet(s, t).toSet();
      final bench = s.crews.entries.where((e) => !active.contains(e.key)).toList()
        ..sort((a, b) => b.value.level.compareTo(a.value.level));
      var next = 0;
      for (var slot = 0; slot < now && next < bench.length; slot++) {
        final id = slot < s.fleet.length ? s.fleet[slot] : null;
        if (id != null && s.crews.containsKey(id)) continue;
        ref.read(fleetCommandsProvider).setSlot(slot, bench[next++].key);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
