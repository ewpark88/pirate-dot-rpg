import 'package:game_core/src/engine/state_parts.dart' show Json;

/// 유료 권리 하나(계약 platform-iap, 세이브 선택 키 `entitlements`): [since]부터 [until]까지(null = 영구).
/// [claimedOn]은 하루 한 번 받는 권리(월간 젬)의 마지막 받은 날(localDate). `product:<id>` 키는 산 기록(첫 구매·계정당 한도).
class Entitlement {
  const Entitlement({required this.since, this.until, this.claimedOn, this.count = 1});

  factory Entitlement.fromJson(Json j) => Entitlement(
    since: DateTime.parse(j['since'] as String),
    until: j['until'] == null ? null : DateTime.parse(j['until'] as String),
    claimedOn: j['claimedOn'] as String?,
    count: j['count'] as int? ?? 1,
  );

  final DateTime since;
  final DateTime? until;
  final String? claimedOn;

  /// 산 횟수(`product:<id>` 기록에서만 씀).
  final int count;

  bool activeAt(DateTime now) => until == null || until!.isAfter(now);

  Entitlement copyWith({DateTime? until, String? claimedOn, int? count}) => Entitlement(
    since: since,
    until: until ?? this.until,
    claimedOn: claimedOn ?? this.claimedOn,
    count: count ?? this.count,
  );

  Json toJson() => {
    'since': since.toUtc().toIso8601String(),
    if (until != null) 'until': until!.toUtc().toIso8601String(),
    if (claimedOn != null) 'claimedOn': claimedOn,
    if (count != 1) 'count': count,
  };
}
