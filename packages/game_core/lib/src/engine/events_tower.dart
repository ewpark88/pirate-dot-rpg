part of 'events.dart';

// 심연의 탑 이벤트 (docs/specs/platform-content-v2.md 4절, 요청 platform-tower.md 3절).

GameEvent _towerEventFromJson(int t, Json j) {
  final floor = j['floor'] as int;
  int n(String k) => j[k] as int? ?? 0;
  return switch (j['type'] as String) {
    'towerStarted' => TowerStarted(t, floor: floor),
    'towerFloorCleared' => TowerFloorCleared(t, floor: floor, gems: n('gems'), cards: n('cards')),
    'towerEnded' => TowerEnded(
      t,
      floor: floor,
      reason: j['reason'] as String,
      kills: n('kills'),
      chestGems: n('chestGems'),
      chestCards: n('chestCards'),
    ),
    _ => TowerSwept(t, floor: floor, chestGems: n('chestGems'), chestCards: n('chestCards')),
  };
}

/// 탑 장면이 열렸다(렌더 '심연의 탑' 띠·UI 시트 닫기).
class TowerStarted extends GameEvent {
  const TowerStarted(super.tick, {required this.floor});

  final int floor;

  @override
  String get type => 'towerStarted';

  @override
  Json _fields() => {'floor': floor};
}

/// 층을 깼다. [gems]·[cards] = 그 층 첫 클리어 보상(이미 받았으면 0).
class TowerFloorCleared extends GameEvent {
  const TowerFloorCleared(super.tick, {required this.floor, this.gems = 0, this.cards = 0});

  final int floor;
  final int gems;
  final int cards;

  @override
  String get type => 'towerFloorCleared';

  @override
  Json _fields() => {'floor': floor, if (gems != 0) 'gems': gems, if (cards != 0) 'cards': cards};
}

/// 탑이 끝났다. [floor] = 마지막으로 깬 층(0이면 1층도 못 깸), [reason] = sunk·retreat·interrupted, 상자 보상.
class TowerEnded extends GameEvent {
  const TowerEnded(
    super.tick, {
    required this.floor,
    required this.reason,
    this.kills = 0,
    this.chestGems = 0,
    this.chestCards = 0,
  });

  final int floor;
  final String reason;
  final int kills;
  final int chestGems;
  final int chestCards;

  @override
  String get type => 'towerEnded';

  @override
  Json _fields() => {
    'floor': floor,
    'reason': reason,
    'kills': kills,
    if (chestGems != 0) 'chestGems': chestGems,
    if (chestCards != 0) 'chestCards': chestCards,
  };
}

/// 소탕: [floor] 층 상자를 바로 받았다.
class TowerSwept extends GameEvent {
  const TowerSwept(super.tick, {required this.floor, this.chestGems = 0, this.chestCards = 0});

  final int floor;
  final int chestGems;
  final int chestCards;

  @override
  String get type => 'towerSwept';

  @override
  Json _fields() => {
    'floor': floor,
    if (chestGems != 0) 'chestGems': chestGems,
    if (chestCards != 0) 'chestCards': chestCards,
  };
}
