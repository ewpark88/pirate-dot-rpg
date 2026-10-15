import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 수동 편성 (사용자 결정: 기본은 수동, ‘자동 편성’으로 한 번에 채우기). 계약 SetFleetSlot·AutoFleet·GameState.fleet(세이브 v5)은
// S1이 추가 중 — 들어오면 두 provider의 본문만 바꾼다. 그 전에는 지금 전장 편성(battle.fleet)을 보여 주고 명령은 보내지 않는다.

/// 출전 칸 수 (렌더 선원 줄 칸과 같다).
const int fleetSlotCount = kSlotCount;

/// 칸별 출전 선원 id (빈 칸 = null, 길이 [fleetSlotCount]).
final fleetSlotsProvider = Provider<List<String?>>((ref) {
  final ids = ref.watch(gameStateProvider.select((s) => s.battle?.fleet.map((f) => f.crewId).join(',') ?? ''));
  final list = ids.isEmpty ? const <String>[] : ids.split(',');
  return [for (var i = 0; i < fleetSlotCount; i++) i < list.length ? list[i] : null];
});

/// 편성 명령. 계약이 오면 `CommandFleet`(SetFleetSlot·AutoFleet 전송)으로 바꾼다.
abstract interface class FleetCommands {
  /// [slot] 칸에 [crewId]를 앉힌다 (null = 비우기). 이미 다른 칸에 있으면 엔진이 옮긴다.
  void setSlot(int slot, String? crewId);

  /// 파워순으로 빈 칸까지 한 번에 채운다.
  void auto();
}

/// 계약 전 자리: 아무것도 보내지 않는다.
class PendingFleetCommands implements FleetCommands {
  const PendingFleetCommands();

  @override
  void setSlot(int slot, String? crewId) {}

  @override
  void auto() {}
}

final fleetCommandsProvider = Provider<FleetCommands>((_) => const PendingFleetCommands());

/// 선원 파워 배율 (경제 `crewPowerMultiplier`) — 후보 정렬·상세 표시.
double crewPowerOf(GameTables t, int level) => crewPowerMultiplier(t.growth, t.rarities, level);
