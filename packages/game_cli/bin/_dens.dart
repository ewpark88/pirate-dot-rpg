import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
void main(List<String> args) {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  final clock = ManualClock(start);
  final e = CoreEngine(tables: t, clock: clock, initial: GameState.newGame(playerId: 'p', seed: int.parse(args[0]), now: start, crews: t.meta.startingCrews));
  e..enqueue(const TutorialAck(1))..enqueue(const UpgradePart('cannon'));
  final mins = int.parse(args[1]);
  final counts = <int>[];
  var wave = 0, boss = 0, empty = 0;
  for (var i = 1; i <= (mins + 10) * 60 * 20; i++) {
    clock.advance(const Duration(milliseconds: 50));
    e.tick();
    e.drainEvents();
    final sec = i ~/ 20;
    if (i % 20 == 0) {
      if (sec % 5 == 0) for (final p in const ['cannon', 'hull', 'sail', 'cargo', 'crowsnest']) { e.enqueue(UpgradePart.max(p)); }
      if (sec % 60 == 30) for (final c in const <Command>[TutorialAck(4), TutorialAck(6), Summon(count: 10), AckSummonResult(), AutoFleet(), MergeAllCards()]) { e.enqueue(c); }
    }
    if (sec >= mins * 60) {
      final b = e.state.battle;
      if (b == null) continue;
      if (b.bossActive) { boss++; continue; }
      final n = b.enemies.where((x) => !x.boss && x.eventKind == null && inCamera(t, x.x, x.y)).length;
      counts.add(n);
      if (n <= 2) empty++;
      wave++;
    }
  }
  counts.sort();
  int q(double p) => counts.isEmpty ? 0 : counts[(counts.length * p).floor().clamp(0, counts.length - 1)];
  print('seed ${args[0]} ${mins}분 뒤 10분: 스테이지 ${e.state.progress.stage} 파밍 ${e.state.progress.farming} · 무리 틱 $wave 보스 틱 $boss · 화면 적 수 10%=${q(0.1)} 중앙=${q(0.5)} 90%=${q(0.9)} · 2마리 이하 ${(empty * 100 / (wave == 0 ? 1 : wave)).round()}%');
}
