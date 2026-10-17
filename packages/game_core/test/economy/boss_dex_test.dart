import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스 종류 늘리기(사용자 2026-10-18 — 해역마다 순환 보스 +3, 6해역 18종) + 도감 보스 능력치(bossDexView, S4 화면).
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);

  test('해역마다 순환 보스 7종(+3), 새 보스는 이름 키·특성 하나·패턴 둘', () {
    for (final r in t.regions.regions) {
      expect(r.bossRotation, hasLength(7), reason: r.id);
    }
    const added = [
      'coral_golem',
      'pearl_clam',
      'storm_eagle',
      'frost_yeti',
      'magma_golem',
      'abyss_eye',
      'ghost_kraken',
    ];
    for (final id in added) {
      final b = t.regions.bosses[id]!;
      expect(b.nameKey, startsWith('econBoss'));
      expect(b.traits, hasLength(1));
      expect(b.patterns, hasLength(2));
    }
  });

  test('bossDexView: 처음 나오는 스테이지 순, 체력·공격은 그 스테이지 기준, 만남·처치 수는 세이브에서', () {
    var s = GameState.newGame(playerId: 'd', seed: 1, now: start);
    s = s.copyWith(
      progress: s.progress.copyWith(
        dex: const DexState(seen: {'clown_king'}, kills: {'enemy_ship': 3}),
      ),
    );
    final rows = bossDexView(s, t);
    expect(rows.length, t.regions.bosses.length);
    final staged = rows.where((r) => r.firstStage > 0).map((r) => r.firstStage).toList();
    expect(staged, orderedEquals([...staged]..sort()));
    final ship = rows.firstWhere((r) => r.id == 'enemy_ship');
    expect((ship.kills, ship.seen), (3, true));
    final clown = rows.firstWhere((r) => r.id == 'clown_king');
    expect((clown.kills, clown.seen), (0, true));
    expect(clown.traits, ['escort']);
    expect(clown.firstStage, greaterThan(0));
    final golem = rows.firstWhere((r) => r.id == 'magma_golem');
    expect(golem.hp > clown.hp, isTrue, reason: '뒤 해역 보스가 더 세다');
    expect(golem.seen, isFalse);
  });
}
