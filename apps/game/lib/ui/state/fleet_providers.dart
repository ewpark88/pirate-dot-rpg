import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 수동 편성 (사용자 결정 2026-10-15, ADR-0010: 기본은 수동, ‘자동 편성’으로 한 번에 채우기).
// 명령은 계약 SetFleetSlot·AutoFleet, 칸은 GameState.fleet(세이브 v5).
// TODO(ui): game_core가 formation.dart(fleetSlots·autoFleet·emptySlotCount)를 export하면 칸 수·첫 틱 전 칸을 그것으로 (S1 요청 중).

/// 출전 칸 수 (렌더 선원 줄 칸과 같다).
const int fleetSlotCount = kSlotCount;

/// 칸별 출전 선원 id (빈 칸 = null, 길이 [fleetSlotCount]). 편성한 적이 없으면(첫 틱 전) 전장 편성을 보인다.
final fleetSlotsProvider = Provider<List<String?>>((ref) {
  final key = ref.watch(
    gameStateProvider.select((s) {
      final ids = s.fleetInit ? s.fleet : (s.battle?.fleet.map((f) => f.crewId).toList() ?? const <String>[]);
      return ids.map((id) => id ?? '').join(',');
    }),
  );
  final list = key.isEmpty ? const <String>[] : key.split(',');
  return [for (var i = 0; i < fleetSlotCount; i++) i < list.length && list[i].isNotEmpty ? list[i] : null];
});

/// 편성 명령.
abstract interface class FleetCommands {
  /// [slot] 칸에 [crewId]를 앉힌다 (null = 비우기). 다른 칸에 있던 선원이면 엔진이 두 칸을 바꾼다.
  void setSlot(int slot, String? crewId);

  /// 파워순으로 칸을 한 번에 채운다 (같은 계열 상한은 엔진이 지킨다).
  void auto();
}

/// 계약 명령을 보낸다.
class CommandFleet implements FleetCommands {
  const CommandFleet(this.sink);

  final CommandSink sink;

  @override
  void setSlot(int slot, String? crewId) => sink.send(SetFleetSlot(slot, crewId));

  @override
  void auto() => sink.send(const AutoFleet());
}

final fleetCommandsProvider = Provider<FleetCommands>((ref) => CommandFleet(ref.watch(commandSinkProvider)));

/// 선원 파워 배율 (경제 `crewPowerMultiplier`) — 후보 정렬·상세 표시.
double crewPowerOf(GameTables t, int level) => crewPowerMultiplier(t.growth, t.rarities, level);
