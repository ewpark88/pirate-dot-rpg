import 'package:game_core/src/engine/state_parts.dart' show Json;
import 'package:meta/meta.dart';

// 심연의 탑 세이브 (docs/specs/platform-content-v2.md 4절, 요청 platform-tower.md 1절). 선택 키 `tower` — 없으면 null,
// 열림 조건을 만족한 첫 틱에 경제가 채운다(ensureTower). 세이브 버전은 올리지 않는다(현상금 bounty와 같은 방식).

/// 탑 진행 상태.
@immutable
class TowerState {
  const TowerState({this.tickets = 0, this.refilledOn, this.adOn, this.best = 0, this.firstCleared = 0, this.active});

  factory TowerState.fromJson(Json j) => TowerState(
    tickets: j['tickets'] as int? ?? 0,
    refilledOn: j['refilledOn'] as String?,
    adOn: j['adOn'] as String?,
    best: j['best'] as int? ?? 0,
    firstCleared: j['firstCleared'] as int? ?? 0,
    active: j['active'] == null ? null : TowerActive.fromJson(j['active'] as Json),
  );

  /// 남은 도전권.
  final int tickets;

  /// 마지막 충전 현지 날짜(yyyy-MM-dd).
  final String? refilledOn;

  /// 광고 도전권을 받은 현지 날짜(하루 1).
  final String? adOn;

  /// 깬 최고 층.
  final int best;

  /// 첫 클리어 보상을 받은 가장 높은 층.
  final int firstCleared;

  /// 진행 중인 탑. 세이브에 남아 있으면 앱이 꺼졌던 것 → 불러올 때 중단(interrupted) 처리.
  final TowerActive? active;

  TowerState copyWith({
    int? tickets,
    String? refilledOn,
    String? adOn,
    int? best,
    int? firstCleared,
    TowerActive? active,
    bool clearActive = false,
  }) => TowerState(
    tickets: tickets ?? this.tickets,
    refilledOn: refilledOn ?? this.refilledOn,
    adOn: adOn ?? this.adOn,
    best: best ?? this.best,
    firstCleared: firstCleared ?? this.firstCleared,
    active: clearActive ? null : active ?? this.active,
  );

  Json toJson() => {
    'tickets': tickets,
    if (refilledOn != null) 'refilledOn': refilledOn,
    if (adOn != null) 'adOn': adOn,
    'best': best,
    'firstCleared': firstCleared,
    if (active != null) 'active': active!.toJson(),
  };
}

/// 진행 중인 탑 — 지금 층.
@immutable
class TowerActive {
  const TowerActive({required this.floor});

  factory TowerActive.fromJson(Json j) => TowerActive(floor: j['floor'] as int);

  final int floor;

  Json toJson() => {'floor': floor};
}
