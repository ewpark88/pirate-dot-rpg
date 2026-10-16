import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 바다 괴물 도감 경제 계약 (S1 2026-10-16): 만남·처치 수·첫 처치 젬, 세이브 선택 키 progress.dex.
void main() {
  final t = EconomyHarness.tables;
  final h = EconomyHarness();

  ({GameState s, List<GameEvent> events}) record(
    GameState s, {
    List<String> present = const [],
    Map<String, int> killed = const {},
  }) {
    final events = <GameEvent>[];
    final ctx = SystemContext(
      tables: t,
      clock: ManualClock(EconomyHarness.start),
      rng: XorShiftRng(1),
      onEvent: events.add,
    );
    return (s: recordDex(s, ctx, present: present, killed: killed), events: events);
  }

  test('도감 칸 = 표의 잡몹(분열 자식 빼고) + 보스, 촉수 같은 부속은 없다', () {
    final c = dexCatalog(t);
    expect(c['crab'], isFalse);
    expect(c[t.regions.regions.first.boss], isTrue);
    expect(c.keys.where((id) => id.endsWith('_small')), isEmpty);
    expect(c.keys.where((id) => id.endsWith('_tentacle')), isEmpty);
  });

  test('만남은 한 번만 DexSeen, 첫 처치에만 젬 + DexFirstKill, 처치 수는 쌓인다', () {
    final s0 = h.newGame();
    final a = record(s0, present: ['crab', 'crab', 'boss_tentacle_x']);
    expect(a.s.progress.dex.seen, {'crab'});
    expect(a.events.whereType<DexSeen>().map((e) => e.id), ['crab']);
    final b = record(a.s, present: ['crab'], killed: {'crab': 2});
    expect(b.events.whereType<DexSeen>(), isEmpty);
    expect(b.events.whereType<DexFirstKill>().single.gems, dexFirstKillGems(t, boss: false));
    expect(b.s.wallet.gems, s0.wallet.gems + dexFirstKillGems(t, boss: false));
    final c = record(b.s, killed: {'crab': 3});
    expect(c.events.whereType<DexFirstKill>(), isEmpty);
    expect(c.s.progress.dex.killsOf('crab'), 5);
    expect(c.s.wallet.gems, b.s.wallet.gems);
    expect(dexFirstKillGems(t, boss: false), 5);
    expect(dexFirstKillGems(t, boss: true), 5);
  });

  test('세이브: 비어 있으면 본문에 없음(옛 세이브 그대로), 있으면 되읽는다, 환생해도 유지', () {
    final s0 = h.newGame();
    expect(s0.progress.toJson().containsKey('dex'), isFalse);
    final s = record(s0, present: ['crab'], killed: {'crab': 1}).s;
    final back = Progress.fromJson(s.progress.toJson());
    expect(back.dex.seen, {'crab'});
    expect(back.dex.killsOf('crab'), 1);
    expect(Progress.fromJson(s0.progress.toJson()).dex.isEmpty, isTrue);
  });
}
