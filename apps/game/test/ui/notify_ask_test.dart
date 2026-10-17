import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/offline/notify_ask.dart';

import 'ui_harness.dart';

// 알림 권한 좋은 때에 (S1 2026-10-18): 처음엔 묻고, 거절이면 7일 뒤 한 번만, 허락이면 다시 안 묻는다 · 설정 알림이 꺼져 있으면 안 묻는다.

GameState _hints(GameState s, List<String> hints, {bool notifications = true}) => s.copyWith(
  settings: Settings.fromJson({
    ...s.settings.toJson(),
    'battleView': s.settings.battleView,
    'hints': hints,
    'notifications': notifications,
  }),
);

void main() {
  final s = loadFixture('stage37_midgame');
  final now = DateTime(2026, 10, 18);

  test('처음 · 거절 7일 뒤 한 번 · 허락이면 끝 · 알림 꺼짐이면 안 물음', () {
    expect(shouldAskNotify(_hints(s, []), now), isTrue);
    expect(shouldAskNotify(_hints(s, ['notify.ask@2026-10-15']), now), isFalse);
    expect(shouldAskNotify(_hints(s, ['notify.ask@2026-10-10']), now), isTrue);
    expect(shouldAskNotify(_hints(s, ['notify.ask@2026-10-01', 'notify.ask2']), now), isFalse);
    expect(shouldAskNotify(_hints(s, [notifyGranted]), now), isFalse);
    expect(shouldAskNotify(_hints(s, [], notifications: false), now), isFalse);
  });

  testWidgets('옥토 창 [좋아요] → 시스템 권한 → 허락 기록, 처음 묻는 날도 기록', (tester) async {
    var asked = 0;
    final log = await pumpGame(
      tester,
      _hints(s, []),
      openTab: false,
      overrides: [
        notifyPermissionProvider.overrideWithValue(() async {
          asked++;
          return true;
        }),
      ],
    );
    final element = tester.element(find.byType(HomeScreen));
    maybeAskNotify(element).ignore();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notify.ask')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notify.yes')));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(log.hints.map((h) => h.id), [startsWith(notifyAskPrefix), notifyGranted]);
  });
}
