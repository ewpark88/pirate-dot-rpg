import 'package:game_core/src/engine/state_parts.dart' show Json;
import 'package:meta/meta.dart';

// 현상금 사냥 세이브·보상 (docs/specs/platform-content-bounty.md 4·5절, 요청 platform-bounty-b0b2.md B0).
// 세이브 v6의 `bounty` 키 그대로(마이그레이션 없음). 키가 없으면 null — 경제가 첫 틱에 표 값으로 채운다(ensureBounty).

/// 현상금 진행 상태.
@immutable
class BountyState {
  const BountyState({
    this.tickets = 0,
    this.refilledOn,
    this.cleared = const {},
    this.progress = const {},
    this.adOn,
    this.active,
    this.weekday,
  });

  factory BountyState.fromJson(Json j) => BountyState(
    tickets: j['tickets'] as int? ?? 0,
    refilledOn: j['refilledOn'] as String?,
    cleared: {...?(j['cleared'] as Map?)?.cast<String, int>()},
    progress: {
      for (final e in ((j['progress'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble(),
    },
    adOn: j['adOn'] as String?,
    active: j['active'] == null ? null : BountyActive.fromJson(j['active'] as Json),
  );

  /// 남은 티켓.
  final int tickets;

  /// 마지막 충전 현지 날짜(yyyy-MM-dd).
  final String? refilledOn;

  /// 보스별 깬 최고 단계.
  final Map<String, int> cleared;

  /// 보스별 다음 단계 최고 피해 비율 0~1 (UI 막대).
  final Map<String, double> progress;

  /// 광고 티켓을 받은 현지 날짜(하루 1).
  final String? adOn;

  /// 진행 중인 현상금 전투. 세이브에 남아 있으면 앱이 꺼졌던 것 → 불러올 때 실패(interrupted) 처리.
  final BountyActive? active;

  /// 운영자 요일 고정 1~7 (OpSetWeekday). 세이브에 남지 않는다(toJson에서 뺀다).
  final int? weekday;

  BountyState copyWith({
    int? tickets,
    String? refilledOn,
    Map<String, int>? cleared,
    Map<String, double>? progress,
    String? adOn,
    BountyActive? active,
    bool clearActive = false,
    int? weekday,
    bool clearWeekday = false,
  }) => BountyState(
    tickets: tickets ?? this.tickets,
    refilledOn: refilledOn ?? this.refilledOn,
    cleared: cleared ?? this.cleared,
    progress: progress ?? this.progress,
    adOn: adOn ?? this.adOn,
    active: clearActive ? null : active ?? this.active,
    weekday: clearWeekday ? null : weekday ?? this.weekday,
  );

  Json toJson() => {
    'tickets': tickets,
    if (refilledOn != null) 'refilledOn': refilledOn,
    if (cleared.isNotEmpty) 'cleared': cleared,
    if (progress.isNotEmpty) 'progress': progress,
    if (adOn != null) 'adOn': adOn,
    if (active != null) 'active': active!.toJson(),
  };
}

/// 진행 중인 현상금 전투.
@immutable
class BountyActive {
  const BountyActive({required this.bossId, required this.tier});

  factory BountyActive.fromJson(Json j) => BountyActive(bossId: j['bossId'] as String, tier: j['tier'] as int);

  final String bossId;
  final int tier;

  Json toJson() => {'bossId': bossId, 'tier': tier};
}

/// 현상금 보상 한 묶음. type: gems | cards | mapPieces | gifts(crew-bond 전까지 젬으로 지급).
/// cards면 [crewId]가 받은 선원(여러 장이면 같은 선원 — 결정론 추첨 1회).
@immutable
class BountyReward {
  const BountyReward({required this.type, required this.amount, this.crewId});

  factory BountyReward.fromJson(Json j) =>
      BountyReward(type: j['type'] as String, amount: j['amount'] as int, crewId: j['crewId'] as String?);

  final String type;
  final int amount;
  final String? crewId;

  Json toJson() => {'type': type, 'amount': amount, if (crewId != null) 'crewId': crewId};

  @override
  bool operator ==(Object other) =>
      other is BountyReward && other.type == type && other.amount == amount && other.crewId == crewId;

  @override
  int get hashCode => Object.hash(type, amount, crewId);
}
