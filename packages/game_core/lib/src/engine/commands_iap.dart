part of 'commands.dart';

// 유료 상품 명령 (계약 platform-iap — 이름은 S5 요청서 그대로, 기획 docs/specs/economy-iap.md).
// 앱이 스토어 결과를 명령으로 넣는다(결정론 밖은 포트에서 끝).

const _iapTypes = {'grantPurchase', 'revokeEntitlement', 'op.setEntitlement', 'claimGemSub', 'claimPassReward'};

Command _iapCommandFromJson(String type, Json j) => switch (type) {
  'grantPurchase' => GrantPurchase(j['productId'] as String, j['token'] as String, DateTime.parse(j['at'] as String)),
  'revokeEntitlement' => RevokeEntitlement(j['id'] as String),
  'op.setEntitlement' => OpSetEntitlement(j['id'] as String, on: j['on'] as bool),
  'claimPassReward' => ClaimPassReward(paid: j['paid'] as bool),
  _ => const ClaimGemSub(),
};

/// 스토어가 '지급해도 됨'을 준 구매([token]은 영수증 토큰, [at]은 구매 시각). 토큰이 처음이면 iap.json대로 지급하고 토큰을 기억한다.
/// 모르는 상품·이미 쓴 토큰·계정당 한도를 넘은 상품이면 아무것도 안 함(앱은 그래도 complete를 부른다).
class GrantPurchase extends Command {
  const GrantPurchase(this.productId, this.token, this.at);

  final String productId;
  final String token;
  final DateTime at;

  @override
  String get type => 'grantPurchase';

  @override
  Json _fields() => {'productId': productId, 'token': token, 'at': at.toUtc().toIso8601String()};
}

/// 권리 끄기(구독 만료·환불 — 복원 조회에서 사라짐).
class RevokeEntitlement extends Command {
  const RevokeEntitlement(this.id);

  final String id;

  @override
  String get type => 'revokeEntitlement';

  @override
  Json _fields() => {'id': id};
}

/// 운영자: 권리 켜기/끄기(실제 결제 없음, 영구). 처리하면 GameState.operator = true(OperatorCommand).
class OpSetEntitlement extends OperatorCommand {
  const OpSetEntitlement(this.id, {required this.on});

  final String id;
  final bool on;

  @override
  String get type => 'op.setEntitlement';

  @override
  Json _fields() => {'id': id, 'on': on};
}

/// 월간 젬: 구독 중이면 하루 한 번 iap.gemSubDaily젬(못 받은 날은 사라짐).
class ClaimGemSub extends Command {
  const ClaimGemSub();

  @override
  String get type => 'claimGemSub';
}

/// 항해 패스 다음 단계 보상 받기 — [paid]면 유료 줄(pass 권리 필요). 그 단계에 닿지 않았으면 그대로.
class ClaimPassReward extends Command {
  const ClaimPassReward({required this.paid});

  final bool paid;

  @override
  String get type => 'claimPassReward';

  @override
  Json _fields() => {'paid': paid};
}
