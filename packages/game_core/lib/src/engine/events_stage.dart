part of 'events.dart';

// 배 피해·파·보스 진행 이벤트 (events.dart가 300줄을 넘어 나눔).

class ShipDamaged extends GameEvent {
  const ShipDamaged(super.tick, {required this.amount, required this.hpRatio, this.fromX, this.fromY});

  final BigNum amount;
  final double hpRatio;

  /// 때린 쪽 위치(선택, 탑다운 피격 방향 연출). 없으면 본문에 없다.
  final double? fromX;
  final double? fromY;

  @override
  String get type => 'shipDamaged';

  @override
  Json _fields() => {
    'amount': amount.toJson(),
    'hpRatio': hpRatio,
    if (fromX != null) 'fromX': fromX,
    if (fromY != null) 'fromY': fromY,
  };
}

class WaveCleared extends GameEvent {
  const WaveCleared(super.tick, {required this.wave});

  final int wave;

  @override
  String get type => 'waveCleared';

  @override
  Json _fields() => {'wave': wave};
}

class BossSpawned extends GameEvent {
  const BossSpawned(super.tick, {required this.kind, required this.timeLimitTicks});

  final String kind;
  final int timeLimitTicks;

  @override
  String get type => 'bossSpawned';

  @override
  Json _fields() => {'kind': kind, 'timeLimitTicks': timeLimitTicks};
}

class BossCleared extends GameEvent {
  const BossCleared(super.tick, {required this.stage, required this.gems});

  final int stage;
  final int gems;

  @override
  String get type => 'bossCleared';

  @override
  Json _fields() => {'stage': stage, 'gems': gems};
}

/// 제한 시간 초과 또는 배 침몰 → 파밍 모드.
class BossFailed extends GameEvent {
  const BossFailed(super.tick, {required this.stage});

  final int stage;

  @override
  String get type => 'bossFailed';

  @override
  Json _fields() => {'stage': stage};
}

/// 화물칸(골드 금고)이 가득 차 [lost]만큼 버렸다 — 렌더 '화물칸 가득!'·UI 경고 (economy-cargo-capacity). 전투 골드는 0.5초마다 묶는다.
class GoldOverflow extends GameEvent {
  const GoldOverflow(super.tick, {required this.lost});

  final BigNum lost;

  @override
  String get type => 'goldOverflow';

  @override
  Json _fields() => {'lost': lost.toJson()};
}
