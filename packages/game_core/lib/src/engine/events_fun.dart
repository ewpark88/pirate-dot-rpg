part of 'events.dart';

// 지루함 해소 3종: 항해 돌발 이벤트·피버·즉석 도전 (docs/specs/platform-fun-sea-events.md, platform-fun-fever.md).

GameEvent _funEventFromJson(int t, Json j) {
  BigNum? big(String k) => j[k] == null ? null : BigNum.parse(j[k] as String);
  return switch (j['type'] as String) {
    'seaEventStarted' => SeaEventStarted(t, id: j['id'] as String, untilTick: j['untilTick'] as int),
    'seaEventEnded' => SeaEventEnded(t, id: j['id'] as String, result: j['result'] as String),
    'goldfishCaught' => GoldfishCaught(
      t,
      targetId: j['targetId'] as int,
      gold: big('gold')!,
      auto: j['auto'] as bool? ?? false,
    ),
    'bottleOpened' => BottleOpened(t, choices: (j['choices'] as List).cast<String>()),
    'bottlePicked' => BottlePicked(
      t,
      index: j['index'] as int,
      reward: j['reward'] as String,
      auto: j['auto'] as bool? ?? false,
    ),
    'feverStarted' => FeverStarted(t, untilTick: j['untilTick'] as int),
    'feverEnded' => FeverEnded(t),
    'challengeStarted' => ChallengeStarted(
      t,
      id: j['id'] as String,
      target: j['target'] as int,
      untilTick: j['untilTick'] as int,
    ),
    'challengeProgress' => ChallengeProgress(t, id: j['id'] as String, value: j['value'] as int),
    _ => ChallengeEnded(t, id: j['id'] as String, success: j['success'] as bool, reward: j['reward'] as String?),
  };
}

/// 돌발 이벤트 시작. [id]: goldfish | merchant | ambush | bottle | storm.
class SeaEventStarted extends GameEvent {
  const SeaEventStarted(super.tick, {required this.id, required this.untilTick});

  final String id;
  final int untilTick;

  @override
  String get type => 'seaEventStarted';

  @override
  Json _fields() => {'id': id, 'untilTick': untilTick};
}

/// 돌발 이벤트 끝. [result]: `done`(잡음·고름) | `left`(시간이 다 됨 — 실패 아님, 벌칙 없음).
class SeaEventEnded extends GameEvent {
  const SeaEventEnded(super.tick, {required this.id, required this.result});

  final String id;
  final String result;

  @override
  String get type => 'seaEventEnded';

  @override
  Json _fields() => {'id': id, 'result': result};
}

/// 황금 물고기 한 마리 (탭, 또는 [auto] = 끝날 때 배가 자동으로 잡은 몫).
class GoldfishCaught extends GameEvent {
  const GoldfishCaught(super.tick, {required this.targetId, required this.gold, this.auto = false});

  final int targetId;
  final BigNum gold;
  final bool auto;

  @override
  String get type => 'goldfishCaught';

  @override
  Json _fields() => {'targetId': targetId, 'gold': gold.toJson(), if (auto) 'auto': true};
}

/// 유리병이 떠옴 — 쪽지 종류(gold | tailwind | gift). UI는 전장 안 말풍선으로 고르게 한다.
class BottleOpened extends GameEvent {
  const BottleOpened(super.tick, {required this.choices});

  final List<String> choices;

  @override
  String get type => 'bottleOpened';

  @override
  Json _fields() => {'choices': choices};
}

/// 쪽지 고름 (또는 [auto] = 시간이 다 돼 첫 쪽지). [reward]는 표시용 요약(예: `gold:1.2e5`, `tailwind:600`, `gems:5`).
class BottlePicked extends GameEvent {
  const BottlePicked(super.tick, {required this.index, required this.reward, this.auto = false});

  final int index;
  final String reward;
  final bool auto;

  @override
  String get type => 'bottlePicked';

  @override
  Json _fields() => {'index': index, 'reward': reward, if (auto) 'auto': true};
}

/// 피버 시작 (공격 ×damageMultiplier, 처치 골드 ×goldMultiplier). [untilTick]까지.
class FeverStarted extends GameEvent {
  const FeverStarted(super.tick, {required this.untilTick});

  final int untilTick;

  @override
  String get type => 'feverStarted';

  @override
  Json _fields() => {'untilTick': untilTick};
}

class FeverEnded extends GameEvent {
  const FeverEnded(super.tick);

  @override
  String get type => 'feverEnded';

  @override
  Json _fields() => const {};
}

/// 즉석 도전 시작. [id]: kills | combo | noHit | ultimate. [target]은 목표 수(noHit은 0).
class ChallengeStarted extends GameEvent {
  const ChallengeStarted(super.tick, {required this.id, required this.target, required this.untilTick});

  final String id;
  final int target;
  final int untilTick;

  @override
  String get type => 'challengeStarted';

  @override
  Json _fields() => {'id': id, 'target': target, 'untilTick': untilTick};
}

/// 도전 진행 (값이 바뀔 때만).
class ChallengeProgress extends GameEvent {
  const ChallengeProgress(super.tick, {required this.id, required this.value});

  final String id;
  final int value;

  @override
  String get type => 'challengeProgress';

  @override
  Json _fields() => {'id': id, 'value': value};
}

/// 도전 끝. 실패는 보상·벌칙 없이 조용히. [reward]는 표시용 요약(성공일 때만).
class ChallengeEnded extends GameEvent {
  const ChallengeEnded(super.tick, {required this.id, required this.success, this.reward});

  final String id;
  final bool success;
  final String? reward;

  @override
  String get type => 'challengeEnded';

  @override
  Json _fields() => {'id': id, 'success': success, if (reward != null) 'reward': reward};
}
