part of 'commands.dart';

// 환생 v2 명령 (docs/specs/platform-rebirth-v2.md 6절).

/// 보물지도 상점에서 [id] 한 레벨 구매 (조각 부족·잠긴 줄·상한이면 무시).
class BuyRebirthUpgrade extends Command {
  const BuyRebirthUpgrade(this.id);

  final String id;

  @override
  String get type => 'buyRebirthUpgrade';

  @override
  Json _fields() => {'id': id};
}

/// 환생 스킨 장착 (null = 기본 배). 갖지 않은 스킨은 무시.
class SelectShipSkin extends Command {
  const SelectShipSkin([this.id]);

  final String? id;

  @override
  String get type => 'selectShipSkin';

  @override
  Json _fields() => {'id': id};
}

/// 칭호 고르기 (null = 없음). 얻지 않은 칭호는 무시.
class SelectTitle extends Command {
  const SelectTitle([this.id]);

  final String? id;

  @override
  String get type => 'selectTitle';

  @override
  Json _fields() => {'id': id};
}

/// 다음 환생에 적용할 보물 바다 항로 (null = 끔). 해금되지 않은 해역은 무시.
class SetTreasureRoute extends Command {
  const SetTreasureRoute([this.sea]);

  final int? sea;

  @override
  String get type => 'setTreasureRoute';

  @override
  Json _fields() => {'sea': sea};
}

/// 운영자: 지도 조각 지급 (쓸 조각·누계 둘 다).
class OpGrantPieces extends OperatorCommand {
  const OpGrantPieces(this.count);

  final int count;

  @override
  String get type => 'op.grantPieces';

  @override
  Json _fields() => {'count': count};
}

/// 운영자: 환생 횟수 지정 (해금·스킨·칭호 확인용, 상자는 주지 않는다).
class OpSetRebirths extends OperatorCommand {
  const OpSetRebirths(this.count);

  final int count;

  @override
  String get type => 'op.setRebirths';

  @override
  Json _fields() => {'count': count};
}
