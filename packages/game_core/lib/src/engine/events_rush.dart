part of 'events.dart';

// 보스 러시 이벤트 (docs/specs/platform-boss-rush.md 3절).

GameEvent _rushEventFromJson(int t, Json j) {
  int n(String k) => j[k] as int? ?? 0;
  return switch (j['type'] as String) {
    'rushStarted' => RushStarted(t, bosses: [...(j['bosses'] as List).cast<String>()]),
    'rushBossDown' => RushBossDown(t, index: n('index'), bossId: j['bossId'] as String, ticks: n('ticks')),
    _ => RushEnded(
      t,
      killed: n('killed'),
      ticks: n('ticks'),
      reason: j['reason'] as String,
      gems: n('gems'),
      pieces: n('pieces'),
      best: j['best'] as bool? ?? false,
    ),
  };
}

/// 러시가 열렸다 — 이번 주 보스 5마리(나오는 차례).
class RushStarted extends GameEvent {
  const RushStarted(super.tick, {required this.bosses});

  final List<String> bosses;

  @override
  String get type => 'rushStarted';

  @override
  Json _fields() => {'bosses': bosses};
}

/// [index]번째(0부터) 보스 [bossId]를 [ticks]틱에 잡았다(렌더 다음 보스 짧은 컷인).
class RushBossDown extends GameEvent {
  const RushBossDown(super.tick, {required this.index, required this.bossId, required this.ticks});

  final int index;
  final String bossId;
  final int ticks;

  @override
  String get type => 'rushBossDown';

  @override
  Json _fields() => {'index': index, 'bossId': bossId, 'ticks': ticks};
}

/// 러시 끝: 잡은 수·걸린 틱·이유(cleared·sunk·retreat·interrupted)·보상, [best] = 이번 주 최고 기록을 바꿨다.
class RushEnded extends GameEvent {
  const RushEnded(
    super.tick, {
    required this.killed,
    required this.ticks,
    required this.reason,
    this.gems = 0,
    this.pieces = 0,
    this.best = false,
  });

  final int killed;
  final int ticks;
  final String reason;
  final int gems;
  final int pieces;
  final bool best;

  @override
  String get type => 'rushEnded';

  @override
  Json _fields() => {
    'killed': killed,
    'ticks': ticks,
    'reason': reason,
    if (gems != 0) 'gems': gems,
    if (pieces != 0) 'pieces': pieces,
    if (best) 'best': best,
  };
}
