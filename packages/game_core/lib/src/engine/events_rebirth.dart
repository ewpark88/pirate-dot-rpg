part of 'events.dart';

// 환생 이벤트 (환생 v2: docs/specs/platform-rebirth-v2.md 6절).

GameEvent _rebirthEventFromJson(int t, Json j) => switch (j['type'] as String) {
  'rebirthDone' => RebirthDone(
    t,
    gain: j['gain'] as int,
    pieces: j['pieces'] as int,
    rebirths: j['rebirths'] as int,
    gems: j['gems'] as int? ?? 0,
    summons: j['summons'] as int? ?? 0,
    title: j['title'] as String?,
    skin: j['skin'] as String?,
  ),
  'rebirthUpgradeBought' => RebirthUpgradeBought(t, id: j['id'] as String, level: j['level'] as int),
  'skinUnlocked' => SkinUnlocked(t, id: j['id'] as String),
  _ => ContentUnlocked(t, kind: j['kind'] as String, value: j['value'] as int),
};

/// 환생 완료. 환생 상자 내용(젬·영웅 이상 소환 수·칭호·스킨)은 이미 지급됐고 UI는 이것 하나로 상자 팝업을 연다.
class RebirthDone extends GameEvent {
  const RebirthDone(
    super.tick, {
    required this.gain,
    required this.pieces,
    required this.rebirths,
    this.gems = 0,
    this.summons = 0,
    this.title,
    this.skin,
  });

  final int gain;
  final int pieces;
  final int rebirths;
  final int gems;
  final int summons;
  final String? title;
  final String? skin;

  @override
  String get type => 'rebirthDone';

  @override
  Json _fields() => {
    'gain': gain,
    'pieces': pieces,
    'rebirths': rebirths,
    if (gems != 0) 'gems': gems,
    if (summons != 0) 'summons': summons,
    if (title != null) 'title': title,
    if (skin != null) 'skin': skin,
  };
}

/// 보물지도 상점 구매 (UI 칸 반짝임).
class RebirthUpgradeBought extends GameEvent {
  const RebirthUpgradeBought(super.tick, {required this.id, required this.level});

  final String id;
  final int level;

  @override
  String get type => 'rebirthUpgradeBought';

  @override
  Json _fields() => {'id': id, 'level': level};
}

/// 환생 스킨을 새로 얻었다.
class SkinUnlocked extends GameEvent {
  const SkinUnlocked(super.tick, {required this.id});

  final String id;

  @override
  String get type => 'skinUnlocked';

  @override
  Json _fields() => {'id': id};
}

/// 환생 횟수로 새 콘텐츠가 열렸다. [kind]: `crewMaxLevel` | `treasureSea` | `shopRow`.
class ContentUnlocked extends GameEvent {
  const ContentUnlocked(super.tick, {required this.kind, required this.value});

  final String kind;
  final int value;

  @override
  String get type => 'contentUnlocked';

  @override
  Json _fields() => {'kind': kind, 'value': value};
}
