import 'package:game_core/src/economy/tower.dart' show towerOpen;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';

// 보스 러시 — 경제 (docs/specs/platform-boss-rush.md — S1 승인 2026-10-18). 주간 조합·도전 충전·시작·기록·보상.
// 전투(top_rush.dart)는 rush.active를 보고 장면을 열고, 끝날 때 [rushReward]로 보상을 정한다.

JsonReader rushCfg(GameTables t) => t.meta.raw.obj('rush');

/// [now]가 든 주의 월요일(현지 yyyy-MM-dd).
String rushWeek(DateTime now) {
  final d = DateTime.parse(localDate(now));
  return localDate(d.subtract(Duration(days: d.weekday - DateTime.monday)));
}

/// 이번 주 보스 차례(모두 같은 조합 — M6 랭킹 대비): meta.rush.lineup의 분류 순서대로, 주 번호로 해역을 돌려 고른다.
/// rotation = 해역 순환 보스, region = 해역 보스, wall = 해역 대보스(없으면 해역 보스).
List<String> rushBosses(GameTables t, String week) {
  final regions = t.regions.regions;
  final w = DateTime.parse(week).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay ~/ DateTime.daysPerWeek;
  var k = w;
  return [
    for (final kind in rushCfg(t).strs('lineup'))
      switch ((kind, regions[k++ % regions.length])) {
        ('rotation', final r) when r.bossRotation.isNotEmpty => r.bossRotation[w % r.bossRotation.length],
        ('wall', final r) => r.wallBoss ?? r.regionBoss,
        (_, final r) => r.regionBoss,
      },
  ];
}

/// 매 틱: 열렸는데 상태가 없으면 이번 주 도전 weeklyTickets로 만든다. 주가 바뀐 첫 틱엔 도전을 다시 채우고 기록·구간 보상을 비운다
/// (남은 도전은 그 주 안에 아무 때나 — 매일 들어올 필요 없음).
GameState rushTick(GameState s, SystemContext ctx) {
  final t = ctx.tables;
  final week = rushWeek(ctx.clock.now());
  final r = s.rush;
  if (r == null) {
    if (!towerOpen(s, t)) return s;
    return s.copyWith(
      rush: RushState(week: week, tickets: rushCfg(t).integer('weeklyTickets')),
    );
  }
  if (r.week == week || r.active != null) return s; // 진행 중이면 끝난 뒤에
  return s.copyWith(
    rush: r.copyWith(week: week, tickets: rushCfg(t).integer('weeklyTickets'), clearBest: true, claimed: const []),
  );
}

/// 장면 모드(현상금·탑·러시) 가운데 하나라도 진행 중인가.
bool sceneBusy(GameState s) => s.bounty?.active != null || s.tower?.active != null || s.rush?.active != null;

bool canStartRush(GameState s, GameTables t) {
  final r = s.rush;
  return towerOpen(s, t) && r != null && r.tickets > 0 && !sceneBusy(s);
}

/// StartRush: 도전 −1, 첫 보스부터. 아니면 그대로(거절).
GameState startRush(GameState s, StartRush c, SystemContext ctx) {
  if (!canStartRush(s, ctx.tables)) return s;
  final r = s.rush!;
  return s.copyWith(
    rush: r.copyWith(tickets: r.tickets - 1, active: const RushActive()),
  );
}

/// 러시 보상: 잡은 수 × perBossGems, 다 잡았으면([cleared]) 걸린 틱이 구간 안이고 이번 주 아직 안 받은 구간마다 젬·지도 조각.
/// 돌려주는 상태에 지급·구간 기록·최고 기록이 들어 있다(active는 그대로 — 전투가 지운다).
({GameState state, int gems, int pieces, bool best}) rushReward(
  GameState s,
  GameTables t,
  int killed,
  int ticks, {
  required bool cleared,
}) {
  final c = rushCfg(t);
  final r = s.rush!;
  var gems = killed * c.integer('perBossGems');
  var pieces = 0;
  final claimed = [...r.claimed];
  final ticksPerSec = Duration.millisecondsPerSecond / t.waves.tickMs;
  final brackets = c.objs('brackets');
  for (var i = 0; cleared && i < brackets.length; i++) {
    if (claimed.contains(i) || ticks > brackets[i].number('sec') * ticksPerSec) continue;
    claimed.add(i);
    gems += brackets[i].integer('gems');
    pieces += brackets[i].intOrNull('pieces') ?? 0;
  }
  final best = cleared && (r.bestTicks == null || ticks < r.bestTicks!);
  final paid = s.copyWith(
    wallet: s.wallet.copyWith(gems: s.wallet.gems + gems, mapPieces: s.wallet.mapPieces + pieces),
    progress: s.progress.copyWith(mapPiecesEarned: s.progress.mapPiecesEarned + pieces),
    rush: r.copyWith(claimed: claimed, bestTicks: best ? ticks : null),
  );
  return (state: paid, gems: gems, pieces: pieces, best: best);
}

/// 광고 도전(AdPlacement.rushTicket): +value, 하루 1.
GameState rushAdTicket(GameState s, int value, DateTime now) {
  final r = s.rush;
  if (r == null) return s;
  return s.copyWith(
    rush: r.copyWith(tickets: r.tickets + value, adOn: localDate(now)),
  );
}
