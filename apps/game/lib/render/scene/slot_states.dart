import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 선원 칸 3상태 (사용자 지시 '출전 가능한 슬롯은 다르게 보이게'). 렌더가 그리고, UI(S4)가 같은 규칙으로 탭을 나눈다:
/// [crew] 초상(탭 = 선원 상세), [open] 비었지만 열림(탭 = 편성), [locked] 배 등급 부족(탭 = '스테이지 N에서 열림' 안내).
enum SlotState { crew, open, locked }

/// 칸 [i]의 상태. 열린 칸 수 = 엔진이 실어 보낸 slotsOpen(game_core fleetSlots — 평생 최고 스테이지 기준, 환생해도 유지).
/// 옛 기록(slotsOpen 0)은 지금 스테이지의 배 등급으로 추정.
SlotState slotStateAt(GameTables t, BattleView f, int i) {
  if (i < f.fleet.length) return SlotState.crew;
  final open = f.slotsOpen > 0 ? f.slotsOpen : t.shipTiers.tierAt(f.stage).slots;
  return i < open ? SlotState.open : SlotState.locked;
}

/// 잠긴 칸 [i]가 열리는 스테이지 (그 칸을 처음 여는 배 등급의 stage). 끝까지 없으면 null.
int? slotUnlockStage(GameTables t, int i) {
  for (final tier in t.shipTiers.tiers) {
    if (tier.slots > i) return tier.stage;
  }
  return null;
}
