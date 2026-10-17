import 'package:game_core/src/engine/state_parts.dart' show Json;
import 'package:meta/meta.dart';

// 요일 던전 세이브 (docs/specs/platform-weekday-dungeon.md 4절 — S1 승인 2026-10-18). 선택 키 `dungeon` — 없으면 null,
// 열림(탑과 같은 조건)의 첫 틱에 경제가 채운다. 세이브 버전은 올리지 않는다.

/// 요일 던전 진행 상태.
@immutable
class DungeonState {
  const DungeonState({this.tickets = 0, this.refilledOn, this.adOn, this.cleared = const {}, this.active});

  factory DungeonState.fromJson(Json j) => DungeonState(
    tickets: j['tickets'] as int? ?? 0,
    refilledOn: j['refilledOn'] as String?,
    adOn: j['adOn'] as String?,
    cleared: {...?(j['cleared'] as Map?)?.cast<String, int>()},
    active: j['active'] == null ? null : DungeonActive.fromJson(j['active'] as Json),
  );

  final int tickets;

  /// 마지막 충전 현지 날짜(yyyy-MM-dd).
  final String? refilledOn;

  /// 광고 도전을 받은 현지 날짜(하루 1).
  final String? adOn;

  /// 요일 묶음 id(meta.dungeon.groups[].id) → 깬 최고 단계.
  final Map<String, int> cleared;

  /// 진행 중인 던전. 세이브에 남아 있으면 앱이 꺼졌던 것 → 불러올 때 실패(interrupted, 도전 돌려줌).
  final DungeonActive? active;

  DungeonState copyWith({
    int? tickets,
    String? refilledOn,
    String? adOn,
    Map<String, int>? cleared,
    DungeonActive? active,
    bool clearActive = false,
  }) => DungeonState(
    tickets: tickets ?? this.tickets,
    refilledOn: refilledOn ?? this.refilledOn,
    adOn: adOn ?? this.adOn,
    cleared: cleared ?? this.cleared,
    active: clearActive ? null : active ?? this.active,
  );

  Json toJson() => {
    'tickets': tickets,
    if (refilledOn != null) 'refilledOn': refilledOn,
    if (adOn != null) 'adOn': adOn,
    if (cleared.isNotEmpty) 'cleared': cleared,
    if (active != null) 'active': active!.toJson(),
  };
}

/// 진행 중인 던전 — 요일 묶음·단계.
@immutable
class DungeonActive {
  const DungeonActive({required this.group, required this.step});

  factory DungeonActive.fromJson(Json j) => DungeonActive(group: j['group'] as String, step: j['step'] as int);

  final String group;
  final int step;

  Json toJson() => {'group': group, 'step': step};
}
