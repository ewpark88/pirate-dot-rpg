import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/home_screen.dart';

import 'ui_harness.dart';

// 승급 스테이지 잠금 (S2 PromoteStatus.stageLocked — 첫 전설 유예): 승급 버튼 자리에 자물쇠 + '스테이지 45에서 열림'.

void main() {
  final t = GameTables.load();

  testWidgets('전설로 오르는 승급이 스테이지 45 전이면 잠긴 버튼', (tester) async {
    final base = loadFixture('stage37_midgame');
    final s0 = base.copyWith(progress: base.progress.copyWith(bestStage: 10, stage: 10));
    // 잠기는 레벨을 찾는다(전설로 오르는 승급 문 앞).
    final id = s0.crews.keys.first;
    GameState? locked;
    for (var lv = 1; lv <= 300 && locked == null; lv++) {
      final s = s0.copyWith(crews: {...s0.crews, id: s0.crews[id]!.copyWith(level: lv)});
      if (promoteStatus(s, t, id) == PromoteStatus.stageLocked) locked = s;
    }
    expect(locked, isNotNull, reason: '시험 전제: 잠기는 레벨이 있다');
    await pumpGame(tester, locked!, openTab: false);
    showCrewDetail(tester.element(find.byType(HomeScreen)), t.crews.byId(id)).ignore();
    await tester.pumpAndSettle();
    final btn = find.byKey(Key('crew.detail.promoteLocked.$id'), skipOffstage: false);
    expect(btn, findsOneWidget);
    expect(find.text('Opens at stage 45', skipOffstage: false), findsOneWidget);
  });
}
