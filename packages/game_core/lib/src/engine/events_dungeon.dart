part of 'events.dart';

// 요일 던전 이벤트 (docs/specs/platform-weekday-dungeon.md 4절).

GameEvent _dungeonEventFromJson(int t, Json j) {
  final group = j['group'] as String;
  final step = j['step'] as int;
  return switch (j['type'] as String) {
    'dungeonStarted' => DungeonStarted(
      t,
      group: group,
      step: step,
      crewIds: [...(j['crewIds'] as List).cast<String>()],
    ),
    'dungeonCleared' => DungeonCleared(
      t,
      group: group,
      step: step,
      cards: [...?(j['cards'] as List?)?.cast<String>()],
      gems: j['gems'] as int? ?? 0,
      swept: j['swept'] as bool? ?? false,
    ),
    _ => DungeonFailed(t, group: group, step: step, reason: j['reason'] as String),
  };
}

/// 던전이 열렸다 — 오늘 묶음·단계·임시 출전 선원(렌더 '관통의 날' 띠, UI 시트 닫기).
class DungeonStarted extends GameEvent {
  const DungeonStarted(super.tick, {required this.group, required this.step, required this.crewIds});

  final String group;
  final int step;
  final List<String> crewIds;

  @override
  String get type => 'dungeonStarted';

  @override
  Json _fields() => {'group': group, 'step': step, 'crewIds': crewIds};
}

/// 단계 클리어(또는 소탕 [swept]) — 받은 카드(선원 id, 장마다)·젬.
class DungeonCleared extends GameEvent {
  const DungeonCleared(
    super.tick, {
    required this.group,
    required this.step,
    this.cards = const [],
    this.gems = 0,
    this.swept = false,
  });

  final String group;
  final int step;
  final List<String> cards;
  final int gems;
  final bool swept;

  @override
  String get type => 'dungeonCleared';

  @override
  Json _fields() => {
    'group': group,
    'step': step,
    if (cards.isNotEmpty) 'cards': cards,
    if (gems != 0) 'gems': gems,
    if (swept) 'swept': swept,
  };
}

/// 실패: sunk·retreat·interrupted·timeout — 도전은 돌려준다.
class DungeonFailed extends GameEvent {
  const DungeonFailed(super.tick, {required this.group, required this.step, required this.reason});

  final String group;
  final int step;
  final String reason;

  @override
  String get type => 'dungeonFailed';

  @override
  Json _fields() => {'group': group, 'step': step, 'reason': reason};
}
