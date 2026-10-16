import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

import 'ui_harness.dart';

PixelButton _button(WidgetTester tester, String part) =>
    tester.widget<PixelButton>(find.byKey(Key('ship.upgrade.$part')));

/// 부위 5줄이 모두 지어지게 세로로 긴 화면 (스킨 r1 줄이 높아 S24에서는 아래 줄이 화면 밖).
const _tall = Size(384, 1300);

void main() {
  final tables = GameTables.load();

  testWidgets('기준 4: 부위 5줄, 레벨·효과·비용, 누르면 UpgradePart', (tester) async {
    // 골드는 대포 1번을 살 만큼(표에서 계산 — 경제가 비용을 바꿔도 깨지지 않게).
    final st = loadFixture('stage37_midgame');
    final cannon = tables.shipParts.byId('cannon');
    final rich = st.copyWith(wallet: st.wallet.copyWith(gold: partCost(cannon, st.ship.level('cannon')).times(2)));
    final log = await pumpGame(
      tester,
      withCargoRoom(rich, extra: rich.wallet.gold.times(1e6)),
      tab: shipTab,
      size: _tall,
      fullSheet: true,
    );
    for (final name in ['Cannon', 'Hull', 'Sail', "Crow's Nest", 'Cargo Hold']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    // 레벨은 샘플에서 읽는다(경제가 샘플을 다시 맞춰도 깨지지 않게).
    final cLv = st.ship.level('cannon');
    final sail = tables.shipParts.byId('sail');
    expect(find.text('Lv $cLv'), findsOneWidget);
    expect(find.text('Lv ${st.ship.level('sail')}/${sail.maxLevel}'), findsOneWidget); // 돛은 최대 레벨이 있다
    expect(find.text(partEffect(cannon, cLv).format()), findsOneWidget);
    // 효과 글은 표(ship_parts)에서 계산 — 경제가 숫자를 다시 맞춰도 깨지지 않게.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // 화물칸은 '최대 a → b'(cargo_test).
    for (final id in ['crowsnest', 'sail']) {
      final def = tables.shipParts.byId(id);
      expect(find.text(partEffectText(l10n, def, partEffect(def, st.ship.level(id)))), findsWidgets, reason: id);
    }
    expect(find.text(partCost(cannon, cLv).format()), findsOneWidget);

    await tester.tap(find.byKey(const Key('ship.upgrade.cannon')));
    expect(log.sent.map((c) => c.toJson()), [
      {'type': 'upgradePart', 'part': 'cannon', 'times': 1},
    ]);
  });

  testWidgets('기준 5: 최대 레벨이면 비활성 + MAX', (tester) async {
    final st = loadFixture('all_crews_mythic');
    await pumpGame(tester, st, tab: shipTab, size: _tall, fullSheet: true);
    expect(_button(tester, 'sail').onPressed, isNull);
    expect(_button(tester, 'crowsnest').onPressed, isNull);
    // 배수 알약의 MAX 1개 + 최대 레벨 부위 2개.
    expect(find.text('MAX'), findsNWidgets(3));
    // 최대 레벨이 없는 부위는 MAX 대신 비용을 보인다 (샘플 대포 레벨의 비용).
    expect(find.text(partCost(tables.shipParts.byId('cannon'), st.ship.level('cannon')).format()), findsOneWidget);
    // 큰 배율(화물칸 후반)은 줄여 쓴다 — 줄 넘침 없음(골드 재조정 1f52fc3 뒤 발견).
    expect(tester.takeException(), isNull);
  });

  testWidgets('기준 5: 골드가 모자라면 비활성', (tester) async {
    await pumpGame(tester, loadFixture('new_player'), tab: shipTab, size: _tall, fullSheet: true);
    for (final p in tables.shipParts.parts) {
      expect(_button(tester, p.id).onPressed, isNull, reason: p.id);
    }
  });

  testWidgets('부위마다 아이콘 그림이 있다 (assets/ui/part_<id>.png)', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: shipTab, size: _tall, fullSheet: true);
    for (final p in tables.shipParts.parts) {
      expect(find.byKey(Key('ship.icon.${p.id}')), findsOneWidget, reason: p.id);
      expect(File('assets/ui/part_${p.id}.png').existsSync(), isTrue, reason: p.id);
    }
  });
}
