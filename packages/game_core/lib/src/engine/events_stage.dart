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
  const BossCleared(super.tick, {required this.stage, required this.gems, this.crewDamage = const {}, this.mvp});

  factory BossCleared.fromJson(int t, Json j) => BossCleared(
    t,
    stage: j['stage'] as int,
    gems: j['gems'] as int,
    crewDamage: {
      for (final e in (j['crewDamage'] as Json? ?? const {}).entries) e.key: BigNum.parse(e.value as String),
    },
    mvp: j['mvp'] as String?,
  );

  final int stage;
  final int gems;

  /// 이번 보스전 선원별 실제 피해(보스·분열 몸·촉수, 남은 HP로 자름) — 보스 처치 창(#14). 옛 기록은 빈 맵.
  final Map<String, BigNum> crewDamage;

  /// 보스 피해가 가장 큰 선원(같으면 출전 칸 앞). 선원 피해가 없으면 null.
  final String? mvp;

  @override
  String get type => 'bossCleared';

  @override
  Json _fields() => {
    'stage': stage,
    'gems': gems,
    if (crewDamage.isNotEmpty) 'crewDamage': {for (final e in crewDamage.entries) e.key: e.value.toJson()},
    if (mvp != null) 'mvp': mvp,
  };
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

/// 도감: 처음 만남(전장에 나타남) — 칸이 그림자로 열린다.
class DexSeen extends GameEvent {
  const DexSeen(super.tick, {required this.id, required this.boss});

  final String id;
  final bool boss;

  @override
  String get type => 'dexSeen';

  @override
  Json _fields() => {'id': id, 'boss': boss};
}

/// 도감: 첫 처치 — 모습 공개 + 보상 젬(meta.dex, 이미 지갑에 들어감).
class DexFirstKill extends GameEvent {
  const DexFirstKill(super.tick, {required this.id, required this.boss, required this.gems});

  final String id;
  final bool boss;
  final int gems;

  @override
  String get type => 'dexFirstKill';

  @override
  Json _fields() => {'id': id, 'boss': boss, 'gems': gems};
}
