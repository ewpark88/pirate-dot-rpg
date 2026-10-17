part of 'commands.dart';

/// 운영자 모드 명령 (docs/GAME_DESIGN.md 6.10). 처리하면 GameState.operator = true.
/// 앱에서는 `--dart-define=OPERATOR=true` 빌드에서만 보낸다.
sealed class OperatorCommand extends Command {
  const OperatorCommand();

  factory OperatorCommand._fromJson(String type, Json j) => switch (type) {
    'op.setCrew' => OpSetCrew(j['crewId'] as String, level: j['level'] as int),
    'op.setFleet' => OpSetFleet((j['crewIds'] as List?)?.cast<String>()),
    'op.seaEvent' => OpSeaEvent(j['id'] as String),
    'op.setBountyTickets' => OpSetBountyTickets(j['count'] as int),
    'op.setWeekday' => OpSetWeekday(j['weekday'] as int?),
    'op.grantPieces' => OpGrantPieces(j['count'] as int),
    'op.setRebirths' => OpSetRebirths(j['count'] as int),
    'op.grant' => OpGrant(
      gold: j['gold'] == null ? null : BigNum.parse(j['gold'] as String),
      gems: j['gems'] as int? ?? 0,
      tokens: j['tokens'] as int? ?? 0,
      cards: (j['cards'] as Map?)?.cast<String, int>() ?? const {},
    ),
    'op.setShip' => OpSetShip((j['parts'] as Map).cast<String, int>()),
    'op.jumpStage' => OpJumpStage(j['stage'] as int),
    'op.setWave' => OpSetWave(count: j['count'] as int?, enemyKind: j['enemyKind'] as String?),
    'op.spawnBoss' => OpSpawnBoss(bossId: j['bossId'] as String?),
    'op.bossBreak' => const OpBossBreak(),
    'op.invincible' => OpSetInvincible(on: j['on'] as bool),
    'op.speed' => OpSetSpeed(j['speed'] as int),
    'op.step' => const OpStepTick(),
    'op.castSkill' => OpCastSkill(j['crewId'] as String),
    'op.zeroCooldown' => OpZeroCooldown(on: j['on'] as bool),
    'op.advanceClock' => OpAdvanceClock(Duration(seconds: j['seconds'] as int)),
    'op.rebirthNow' => const OpRebirthNow(),
    'op.loadState' => OpLoadState(GameState.fromJson(j['state'] as Json)),
    'op.reset' => const OpReset(),
    'op.spawnChest' => const OpSpawnChest(),
    'op.setTutorial' => OpSetTutorial(j['step'] as int?),
    'op.grantTailwind' => OpGrantTailwind(Duration(seconds: j['seconds'] as int)),
    _ => throw FormatException('알 수 없는 운영자 명령', type),
  };
}

/// 선원 하나를 아무 레벨(1~75, 등급은 레벨 구간)로 지정. 미보유면 보유로.
class OpSetCrew extends OperatorCommand {
  const OpSetCrew(this.crewId, {required this.level});

  final String crewId;
  final int level;

  @override
  String get type => 'op.setCrew';

  @override
  Json _fields() => {'crewId': crewId, 'level': level};
}

/// 출전 슬롯 직접 배치. null이면 자동 편성으로 돌아간다. 한 명만 넣으면 단독 출전.
class OpSetFleet extends OperatorCommand {
  const OpSetFleet(this.crewIds);

  final List<String>? crewIds;

  @override
  String get type => 'op.setFleet';

  @override
  Json _fields() => {'crewIds': crewIds};
}

/// 재화 지급.
class OpGrant extends OperatorCommand {
  const OpGrant({this.gold, this.gems = 0, this.tokens = 0, this.cards = const {}});

  final BigNum? gold;
  final int gems;
  final int tokens;

  /// 선원 id → 카드 수.
  final Map<String, int> cards;

  @override
  String get type => 'op.grant';

  @override
  Json _fields() => {'gold': gold?.toJson(), 'gems': gems, 'tokens': tokens, 'cards': cards};
}

/// 배 부위 레벨 지정.
class OpSetShip extends OperatorCommand {
  const OpSetShip(this.parts);

  final Map<String, int> parts;

  @override
  String get type => 'op.setShip';

  @override
  Json _fields() => {'parts': parts};
}

/// 스테이지·해역 점프.
class OpJumpStage extends OperatorCommand {
  const OpJumpStage(this.stage);

  final int stage;

  @override
  String get type => 'op.jumpStage';

  @override
  Json _fields() => {'stage': stage};
}

/// 무리 크기·적 종류 지정. null이면 테이블 기본값.
class OpSetWave extends OperatorCommand {
  const OpSetWave({this.count, this.enemyKind});

  final int? count;
  final String? enemyKind;

  @override
  String get type => 'op.setWave';

  @override
  Json _fields() => {'count': count, 'enemyKind': enemyKind};
}

/// 보스 소환. [bossId]가 있으면 그 보스(특성 보스 시험 — 스테이지의 보스 대신), 없으면 지금 스테이지의 보스.
class OpSpawnBoss extends OperatorCommand {
  const OpSpawnBoss({this.bossId});

  final String? bossId;

  @override
  String get type => 'op.spawnBoss';

  @override
  Json _fields() => {if (bossId != null) 'bossId': bossId};
}

/// 지금 보스의 브레이크 게이지를 가득 — 다음 틱에 쓰러진다(보스 브레이크 시험).
class OpBossBreak extends OperatorCommand {
  const OpBossBreak();

  @override
  String get type => 'op.bossBreak';
}

/// 배 무적.
class OpSetInvincible extends OperatorCommand {
  const OpSetInvincible({required this.on});

  final bool on;

  @override
  String get type => 'op.invincible';

  @override
  Json _fields() => {'on': on};
}

/// 배속: 0(일시정지)·1·2·4.
class OpSetSpeed extends OperatorCommand {
  const OpSetSpeed(this.speed);

  final int speed;

  @override
  String get type => 'op.speed';

  @override
  Json _fields() => {'speed': speed};
}

/// 일시정지 중 1틱 진행.
class OpStepTick extends OperatorCommand {
  const OpStepTick();

  @override
  String get type => 'op.step';
}

/// 선원 스킬 즉시 발동.
class OpCastSkill extends OperatorCommand {
  const OpCastSkill(this.crewId);

  final String crewId;

  @override
  String get type => 'op.castSkill';

  @override
  Json _fields() => {'crewId': crewId};
}

/// 쿨타임 0.
class OpZeroCooldown extends OperatorCommand {
  const OpZeroCooldown({required this.on});

  final bool on;

  @override
  String get type => 'op.zeroCooldown';

  @override
  Json _fields() => {'on': on};
}

/// 가짜 시간 경과 (오프라인 보상·날짜 넘기기 테스트).
class OpAdvanceClock extends OperatorCommand {
  const OpAdvanceClock(this.by);

  final Duration by;

  @override
  String get type => 'op.advanceClock';

  @override
  Json _fields() => {'seconds': by.inSeconds};
}

class OpRebirthNow extends OperatorCommand {
  const OpRebirthNow();

  @override
  String get type => 'op.rebirthNow';
}

/// 샘플 상태(fixtures/states) 불러오기.
class OpLoadState extends OperatorCommand {
  const OpLoadState(this.state);

  final GameState state;

  @override
  String get type => 'op.loadState';

  @override
  Json _fields() => {'state': state.toJson()};
}

/// 세이브 초기화.
class OpReset extends OperatorCommand {
  const OpReset();

  @override
  String get type => 'op.reset';
}

/// 보물상자를 지금 띄운다.
class OpSpawnChest extends OperatorCommand {
  const OpSpawnChest();

  @override
  String get type => 'op.spawnChest';
}

/// 튜토리얼 단계를 지정한다 (null = 끝).
class OpSetTutorial extends OperatorCommand {
  const OpSetTutorial(this.step);

  final int? step;

  @override
  String get type => 'op.setTutorial';

  @override
  Json _fields() => {'step': step};
}

/// 순풍 버프를 [duration]만큼 준다 (광고 없이).
class OpGrantTailwind extends OperatorCommand {
  const OpGrantTailwind(this.duration);

  final Duration duration;

  @override
  String get type => 'op.grantTailwind';

  @override
  Json _fields() => {'seconds': duration.inSeconds};
}
