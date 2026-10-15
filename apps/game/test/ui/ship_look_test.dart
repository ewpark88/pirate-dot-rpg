import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ship/ship_look.dart';

import 'ui_harness.dart';

// 배 외형 축하 (ShipLookChanged): 부위별 큰 글(렌더 S3 표)·팝업 하나만.

void main() {
  test('큰 글 규칙: 돛 5단계 금빛, 대포는 한쪽 포 수가 늘 때만 +1, 선체 5 충각·6 선수상', () async {
    final l = await AppLocalizations.delegate.load(const Locale('ko'));
    expect(shipLookHeadline(l, 'sail', 2), '돛 +1!');
    expect(shipLookHeadline(l, 'sail', 5), '금빛 돛!');
    expect(
      [for (var s = 2; s <= 7; s++) shipLookHeadline(l, 'cannon', s)],
      [
        '대포 +1!',
        '대포 강화!',
        '대포 +1!',
        '대포 강화!',
        '대포 +1!',
        '대포 강화!',
      ],
    );
    expect(shipLookHeadline(l, 'hull', 3), '선체 확장!');
    expect(shipLookHeadline(l, 'hull', 5), '충각 장착!');
    expect(shipLookHeadline(l, 'hull', 6), '선수상!');
    expect(shipLookHeadline(l, 'crowsnest', 2), '망루 강화!');
    expect(shipLookHeadline(l, 'cargo', 2), '짐 +1');
  });

  testWidgets('ShipLookChanged가 연달아 와도 축하 팝업은 하나, 확인으로 닫힌다', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed
      ..add(RecordedTick(s.battle!, const [ShipLookChanged(1, part: 'sail', stage: 2)]))
      ..add(RecordedTick(s.battle!, const [ShipLookChanged(2, part: 'sail', stage: 3)]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ship.look.celebrate')), findsOneWidget);
    expect(find.text('Sail +1!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ship.look.ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ship.look.celebrate')), findsNothing);
  });
}
