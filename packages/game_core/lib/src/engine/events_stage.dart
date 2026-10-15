part of 'events.dart';

// 배 피해·파·보스 진행 이벤트 (events.dart가 300줄을 넘어 나눔).

class ShipDamaged extends GameEvent {
  const ShipDamaged(super.tick, {required this.amount, required this.hpRatio});

  final BigNum amount;
  final double hpRatio;

  @override
  String get type => 'shipDamaged';

  @override
  Json _fields() => {'amount': amount.toJson(), 'hpRatio': hpRatio};
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
