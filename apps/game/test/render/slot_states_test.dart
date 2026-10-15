import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/scene/slot_states.dart';

import 'helpers.dart';

void main() {
  BattleView view(int stage, int crews) => BattleView(
    shipHp: BigNum.one,
    shipHpMax: BigNum.one,
    stage: stage,
    fleet: [for (var i = 0; i < crews; i++) FleetSlot(crewId: tables.crews.crews[i].id)],
  );

  test('칸 3상태: 출전 중 → 열림(배 등급 slots까지) → 잠김', () {
    final f = view(31, 3); // sloop: 4칸
    expect(
      [for (var i = 0; i < 6; i++) slotStateAt(tables, f, i)],
      [
        SlotState.crew,
        SlotState.crew,
        SlotState.crew,
        SlotState.open,
        SlotState.locked,
        SlotState.locked,
      ],
    );
    expect(slotStateAt(tables, view(1, 0), 2), SlotState.open, reason: '첫 배도 3칸');
    expect(slotStateAt(tables, view(150, 6), 5), SlotState.crew);
  });

  test('잠긴 칸이 열리는 스테이지 = 그 칸을 처음 여는 배 등급', () {
    expect(slotUnlockStage(tables, 2), 1);
    expect(slotUnlockStage(tables, 3), 30);
    expect(slotUnlockStage(tables, 4), 80);
    expect(slotUnlockStage(tables, 5), 150);
    expect(slotUnlockStage(tables, 6), isNull);
  });
}
