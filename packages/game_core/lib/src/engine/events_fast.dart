part of 'events.dart';

// 빠른 항해 돌파 이벤트 (docs/specs/platform-fast-sail-breakthrough.md).

GameEvent _fastEventFromJson(int t, Json j) => switch (j['type'] as String) {
  'fastSailStarted' => FastSailStarted(t, from: j['from'] as int, to: j['to'] as int),
  'breakthroughStrike' => BreakthroughStrike(
    t,
    stage: j['stage'] as int,
    bossId: j['bossId'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    combo: j['combo'] as int,
    phase: j['phase'] as String,
    speed: (j['speed'] as num).toDouble(),
  ),
  _ => FastSailEnded(
    t,
    from: j['from'] as int,
    to: j['to'] as int,
    stages: j['stages'] as int,
    gold: BigNum.parse(j['gold'] as String),
    lost: BigNum.parse(j['lost'] as String),
    gems: j['gems'] as int,
    skipped: j['skipped'] as bool,
  ),
};

/// 환생 뒤 빠른 항해 구간 시작: 스테이지 [from]부터 [to]까지 보스를 연달아 돌파한다.
class FastSailStarted extends GameEvent {
  const FastSailStarted(super.tick, {required this.from, required this.to});

  final int from;
  final int to;

  @override
  String get type => 'fastSailStarted';

  @override
  Json _fields() => {'from': from, 'to': to};
}

/// 돌파 구간의 보스 격파 순간(선원이 잡았든 돌파 사격이든). [combo] = 이번 구간 연속 격파 수(1부터), [phase]·[speed] = 리듬.
class BreakthroughStrike extends GameEvent {
  const BreakthroughStrike(
    super.tick, {
    required this.stage,
    required this.bossId,
    required this.x,
    required this.y,
    required this.combo,
    required this.phase,
    required this.speed,
  });

  final int stage;
  final String bossId;
  final double x;
  final double y;
  final int combo;

  /// build(빨라지는 중) | rush(최소 간격 — 순식간) | finale(마지막 스테이지).
  final String phase;

  /// 리듬 배율 = 첫 간격 ÷ 이번 간격(1, 1.33, 1.78 … 최대 첫 ÷ 최소).
  final double speed;

  @override
  String get type => 'breakthroughStrike';

  @override
  Json _fields() => {
    'stage': stage,
    'bossId': bossId,
    'x': x,
    'y': y,
    'combo': combo,
    'phase': phase,
    'speed': speed,
  };
}

/// 돌파 구간 끝: [from] → [to] 스테이지, 돌파한 수 [stages], 그동안 실은 [gold]·넘친 [lost]·[gems]. [skipped] = 건너뛰기로 끝냄.
class FastSailEnded extends GameEvent {
  const FastSailEnded(
    super.tick, {
    required this.from,
    required this.to,
    required this.stages,
    required this.gold,
    required this.lost,
    required this.gems,
    required this.skipped,
  });

  final int from;
  final int to;
  final int stages;
  final BigNum gold;

  /// 화물칸이 차서 싣지 못한 골드(S2 — UI '화물칸이 작아 X를 못 실었어요').
  final BigNum lost;
  final int gems;
  final bool skipped;

  @override
  String get type => 'fastSailEnded';

  @override
  Json _fields() => {
    'from': from,
    'to': to,
    'stages': stages,
    'gold': gold.toJson(),
    'lost': lost.toJson(),
    'gems': gems,
    'skipped': skipped,
  };
}
