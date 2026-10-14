import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

void main() {
  test('샘플 상태를 주입하면 gameStateProvider가 그 상태를 낸다', () {
    final state = loadFixture('stage37_midgame');
    final container = ProviderContainer(overrides: [initialGameStateProvider.overrideWithValue(state)]);
    addTearDown(container.dispose);
    expect(container.read(gameStateProvider).progress.stage, 37);
  });

  test('replace로 바꾼 상태를 구독자가 받는다 (운영자 샘플 불러오기)', () {
    final container = ProviderContainer(
      overrides: [initialGameStateProvider.overrideWithValue(loadFixture('new_player'))],
    );
    addTearDown(container.dispose);
    final seen = <int>[];
    container.listen(gameStateProvider, (_, s) => seen.add(s.progress.stage));
    container.read(gameStateProvider.notifier).replace(loadFixture('boss_fight'));
    expect(seen, [5]);
  });

  test('CommandLog는 보낸 명령을 순서대로 모은다', () {
    final log = CommandLog()
      ..send(const UpgradePart('cannon'))
      ..send(const Summon(count: 10));
    expect(log.sent.map((c) => c.toJson()), [
      {'type': 'upgradePart', 'part': 'cannon', 'times': 1},
      {'type': 'summon', 'count': 10},
    ]);
  });

  test('앱 기본값: 테이블을 읽고 새 게임 상태로 시작한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(tablesProvider).shipParts.parts, hasLength(5));
    expect(container.read(gameStateProvider).progress.stage, 1);
  });
}
