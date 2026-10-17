part of 'commands.dart';

// 지루함 해소: 항해 돌발 이벤트 명령 (docs/specs/platform-fun-sea-events.md 4절).

/// 황금 물고기 한 마리를 탭 (targetId = EnemyView.id, eventKind == 'goldfish').
class TapSeaEvent extends Command {
  const TapSeaEvent(this.targetId);

  final int targetId;

  @override
  String get type => 'tapSeaEvent';

  @override
  Json _fields() => {'targetId': targetId};
}

/// 표류 유리병 쪽지 고르기 (index = meta.seaEvents bottle choices 순번). 병이 없으면 무시.
class PickBottle extends Command {
  const PickBottle(this.index);

  final int index;

  @override
  String get type => 'pickBottle';

  @override
  Json _fields() => {'index': index};
}

/// 운영자: 돌발 이벤트 [id]를 지금 시작 (QA·연출 확인).
class OpSeaEvent extends OperatorCommand {
  const OpSeaEvent(this.id);

  final String id;

  @override
  String get type => 'op.seaEvent';

  @override
  Json _fields() => {'id': id};
}

/// 자동 강화 버프 끄기 — 남은 시간은 버린다(S4 요청, 사용자 '수동으로만').
class CancelAutoUpgrade extends Command {
  const CancelAutoUpgrade();

  @override
  String get type => 'cancelAutoUpgrade';
}

/// 안내 다시 보기(가이드 v2, S4): Settings.hints에서 [prefix]로 시작하는 id를 지운다. 빈 prefix = 전부.
class ClearHints extends Command {
  const ClearHints(this.prefix);

  final String prefix;

  @override
  String get type => 'clearHints';

  @override
  Json _fields() => {'prefix': prefix};
}

/// 안내(말풍선) [id]를 본 것으로 저장 — 이미 있으면 그대로(S4 '처음 1회 안내').
class MarkHint extends Command {
  const MarkHint(this.id);

  final String id;

  @override
  String get type => 'markHint';

  @override
  Json _fields() => {'id': id};
}

/// 조각 스킨 사기(meta.shipSkins source pieces): 보물지도 조각 value개 → 스킨.
class BuySkin extends Command {
  const BuySkin(this.id);

  final String id;

  @override
  String get type => 'buySkin';

  @override
  Json _fields() => {'id': id};
}

/// 도감 수집 보상 받기(meta.collectionRewards, S4 '수집의 재미'): 보유 선원이 [at]명 이상이고 아직 안 받았으면 젬·소환.
class ClaimCollectionReward extends Command {
  const ClaimCollectionReward(this.at);

  final int at;

  @override
  String get type => 'claimCollectionReward';

  @override
  Json _fields() => {'at': at};
}
