import 'package:game_core/src/engine/state_parts.dart' show Json;
import 'package:meta/meta.dart';

// 보스 러시 세이브 (docs/specs/platform-boss-rush.md 3절 — S1 승인 2026-10-18). 선택 키 `rush` — 없으면 null,
// 열림(탑과 같은 조건)의 첫 틱에 경제가 채운다. 세이브 버전은 올리지 않는다(bounty·tower와 같은 방식).

/// 보스 러시 진행 상태(이번 주).
@immutable
class RushState {
  const RushState({this.week, this.tickets = 0, this.adOn, this.bestTicks, this.claimed = const [], this.active});

  factory RushState.fromJson(Json j) => RushState(
    week: j['week'] as String?,
    tickets: j['tickets'] as int? ?? 0,
    adOn: j['adOn'] as String?,
    bestTicks: j['bestTicks'] as int?,
    claimed: [...?(j['claimed'] as List?)?.cast<int>()],
    active: j['active'] == null ? null : RushActive.fromJson(j['active'] as Json),
  );

  /// 이번 주(월요일 현지 날짜 yyyy-MM-dd). 바뀌면 도전 다시 채우고 기록·구간 보상을 비운다.
  final String? week;
  final int tickets;

  /// 광고 도전을 받은 현지 날짜(하루 1).
  final String? adOn;

  /// 이번 주 5마리 처치 최고 기록(틱). 아직 없으면 null.
  final int? bestTicks;

  /// 이번 주 받은 기록 구간(meta.rush.brackets 인덱스).
  final List<int> claimed;

  /// 진행 중인 러시. 세이브에 남아 있으면 앱이 꺼졌던 것 → 불러올 때 중단(interrupted).
  final RushActive? active;

  RushState copyWith({
    String? week,
    int? tickets,
    String? adOn,
    int? bestTicks,
    bool clearBest = false,
    List<int>? claimed,
    RushActive? active,
    bool clearActive = false,
  }) => RushState(
    week: week ?? this.week,
    tickets: tickets ?? this.tickets,
    adOn: adOn ?? this.adOn,
    bestTicks: clearBest ? null : bestTicks ?? this.bestTicks,
    claimed: claimed ?? this.claimed,
    active: clearActive ? null : active ?? this.active,
  );

  Json toJson() => {
    if (week != null) 'week': week,
    'tickets': tickets,
    if (adOn != null) 'adOn': adOn,
    if (bestTicks != null) 'bestTicks': bestTicks,
    if (claimed.isNotEmpty) 'claimed': claimed,
    if (active != null) 'active': active!.toJson(),
  };
}

/// 진행 중인 러시 — 지금 몇 번째 보스(0부터)·지난 틱.
@immutable
class RushActive {
  const RushActive({this.index = 0, this.ticks = 0});

  factory RushActive.fromJson(Json j) => RushActive(index: j['index'] as int? ?? 0, ticks: j['ticks'] as int? ?? 0);

  final int index;
  final int ticks;

  Json toJson() => {'index': index, 'ticks': ticks};
}
