import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:meta/meta.dart';

part 'commands_bounty.dart';
part 'commands_fun.dart';
part 'commands_rebirth.dart';
part 'commands_tower.dart';
part 'operator_commands.dart';

/// 플레이어 입력. UI는 버튼을 누르면 Command만 보낸다. 엔진은 다음 틱에 적용한다.
///
/// JSON 형식(`{"type": ..., ...}`)은 시나리오 리플레이·운영자 로그에 쓴다.
@immutable
sealed class Command {
  const Command();

  factory Command.fromJson(Json j) {
    final type = j['type'] as String;
    return switch (type) {
      'upgradePart' =>
        j['max'] == true
            ? UpgradePart.max(j['part'] as String)
            : UpgradePart(j['part'] as String, times: j['times'] as int? ?? 1),
      'summon' => Summon(count: j['count'] as int? ?? 1),
      'mergeAllCards' => MergeAllCards(crewId: j['crewId'] as String?),
      'promoteCrew' => PromoteCrew(j['crewId'] as String),
      'challengeBoss' => const ChallengeBoss(),
      'triggerUltimate' => const TriggerUltimate(),
      'tapChest' => const TapChest(),
      'grantAdReward' => GrantAdReward(
        AdPlacement.values.byName(j['placement'] as String),
        choice: j['choice'] as String?,
      ),
      'claimOffline' => const ClaimOffline(),
      'claimDaily' => ClaimDaily(j['questId'] as String?),
      'claimAttendance' => const ClaimAttendance(),
      'rebirth' => const Rebirth(),
      'exchangeToken' => ExchangeToken(j['crewId'] as String),
      'setSetting' => SetSetting(j['key'] as String, j['value'] as Object),
      'skipTutorial' => const SkipTutorial(),
      'tutorialAck' => TutorialAck(j['step'] as int),
      'ackSummonResult' => const AckSummonResult(),
      'setFleetSlot' => SetFleetSlot(j['slot'] as int, j['crewId'] as String?),
      'autoFleet' => const AutoFleet(),
      'buyRebirthUpgrade' => BuyRebirthUpgrade(j['id'] as String),
      'selectShipSkin' => SelectShipSkin(j['id'] as String?),
      'selectTitle' => SelectTitle(j['id'] as String?),
      'setTreasureRoute' => SetTreasureRoute(j['sea'] as int?),
      'tapSeaEvent' => TapSeaEvent(j['targetId'] as int),
      'pickBottle' => PickBottle(j['index'] as int),
      'startBounty' => StartBounty(j['bossId'] as String, j['tier'] as int),
      'sweepBounty' => SweepBounty(j['bossId'] as String, j['count'] as int),
      'retreatBounty' => const RetreatBounty(),
      'startTower' => const StartTower(),
      'sweepTower' => const SweepTower(),
      'retreatTower' => const RetreatTower(),
      'cancelAutoUpgrade' => const CancelAutoUpgrade(),
      'markHint' => MarkHint(j['id'] as String),
      'buySkin' => BuySkin(j['id'] as String),
      'claimCollectionReward' => ClaimCollectionReward(j['at'] as int),
      'claimTrial' => ClaimTrial(j['kind'] as String),
      'clearHints' => ClearHints(j['prefix'] as String? ?? ''),
      'skipFastSail' => const SkipFastSail(),
      'startVoyage' => const StartVoyage(),
      _ when type.startsWith('op.') => OperatorCommand._fromJson(type, j),
      _ => throw FormatException('알 수 없는 명령', type),
    };
  }

  /// JSON의 type 값.
  String get type;

  Json toJson() => {'type': type, ..._fields()};

  Json _fields() => const {};

  @override
  String toString() => toJson().toString();
}

/// 배 부위 강화 (골드).
class UpgradePart extends Command {
  const UpgradePart(this.part, {this.times = 1}) : max = false;

  /// ‘최대’ 버튼: 골드로 살 수 있는 만큼 (최대 레벨까지).
  const UpgradePart.max(this.part) : times = 0, max = true;

  /// ship_parts.json의 id.
  final String part;

  /// 일괄 강화 횟수 (UI 1·5·10·20·50). 골드가 모자라면 살 수 있는 만큼만.
  final int times;
  final bool max;

  @override
  String get type => 'upgradePart';

  @override
  Json _fields() => max ? {'part': part, 'max': true} : {'part': part, 'times': times};
}

/// 선원 소환 (젬). 1회 또는 10연.
class Summon extends Command {
  const Summon({this.count = 1});

  final int count;

  @override
  String get type => 'summon';

  @override
  Json _fields() => {'count': count};
}

/// 모든 해적의 합칠 수 있는 카드를 한 번에 합친다. [crewId]가 있으면 그 해적만(선원 상세 '지금 합치기').
class MergeAllCards extends Command {
  const MergeAllCards({this.crewId});
  final String? crewId;

  @override
  String get type => 'mergeAllCards';

  @override
  Json _fields() => {if (crewId != null) 'crewId': crewId};
}

/// 출전 칸 [slot](0부터)에 선원을 넣는다. [crewId]가 null이면 비운다 (수동 편성, ADR-0010).
/// 다른 칸에 있던 선원이면 두 칸이 자리를 바꾼다. 미보유·슬롯 밖은 무시, 같은 계열 상한을 넘기면 거절(FleetRejected).
class SetFleetSlot extends Command {
  const SetFleetSlot(this.slot, [this.crewId]);

  final int slot;
  final String? crewId;

  @override
  String get type => 'setFleetSlot';

  @override
  Json _fields() => {'slot': slot, 'crewId': crewId};
}

/// ‘자동 편성’ 버튼: 파워 순·같은 계열 상한으로 슬롯을 모두 채운다 (설계서 4.3).
class AutoFleet extends Command {
  const AutoFleet();

  @override
  String get type => 'autoFleet';
}

/// 해적 한 명 승급 (연출을 보여주려고 해적별 버튼).
class PromoteCrew extends Command {
  const PromoteCrew(this.crewId);

  final String crewId;

  @override
  String get type => 'promoteCrew';

  @override
  Json _fields() => {'crewId': crewId};
}

/// 파밍 중 보스 도전.
class ChallengeBoss extends Command {
  const ChallengeBoss();

  @override
  String get type => 'challengeBoss';
}

/// 함성 게이지가 가득 찼을 때 궁극기를 직접 터뜨린다 (유일한 선택적 조작).
class TriggerUltimate extends Command {
  const TriggerUltimate();

  @override
  String get type => 'triggerUltimate';
}

/// 떠내려온 보물상자 탭 (기본 보상).
class TapChest extends Command {
  const TapChest();

  @override
  String get type => 'tapChest';
}

/// 보상형 광고의 보상 콜백이 온 뒤에만 보낸다.
class GrantAdReward extends Command {
  const GrantAdReward(this.placement, {this.choice});

  final AdPlacement placement;

  /// 보상을 고르는 장치의 선택 (보물상자: `gold` | `gems`, 설계서 4.6). 없으면 기본 보상.
  final String? choice;

  @override
  String get type => 'grantAdReward';

  @override
  Json _fields() => {'placement': placement.name, if (choice != null) 'choice': choice};
}

/// 복귀 팝업에서 오프라인 보상 받기 (광고 ×2는 GrantAdReward(offline)).
class ClaimOffline extends Command {
  const ClaimOffline();

  @override
  String get type => 'claimOffline';
}

/// 일일 퀘스트 보상 받기 (설계서 4.9: 퀘스트마다 젬). [questId]가 없으면 완료한 퀘스트를 모두 받는다.
class ClaimDaily extends Command {
  const ClaimDaily([this.questId]);

  final String? questId;

  @override
  String get type => 'claimDaily';

  @override
  Json _fields() => {if (questId != null) 'questId': questId};
}

class ClaimAttendance extends Command {
  const ClaimAttendance();

  @override
  String get type => 'claimAttendance';
}

/// 환생(보물지도).
class Rebirth extends Command {
  const Rebirth();

  @override
  String get type => 'rebirth';
}

/// 해적의 증표로 원하는 해적의 카드를 받는다.
class ExchangeToken extends Command {
  const ExchangeToken(this.crewId);

  final String crewId;

  @override
  String get type => 'exchangeToken';

  @override
  Json _fields() => {'crewId': crewId};
}

/// 설정 하나 바꾸기. [key]는 Settings의 필드 이름.
class SetSetting extends Command {
  const SetSetting(this.key, this.value);

  final String key;
  final Object value;

  @override
  String get type => 'setSetting';

  @override
  Json _fields() => {'key': key, 'value': value};
}

/// 튜토리얼 건너뛰기 (설계서 4.12). tutorialStep = null.
class SkipTutorial extends Command {
  const SkipTutorial();

  @override
  String get type => 'skipTutorial';
}

/// 튜토리얼 말풍선을 확인했다 → 다음 단계 판정은 경제 레인.
class TutorialAck extends Command {
  const TutorialAck(this.step);

  final int step;

  @override
  String get type => 'tutorialAck';

  @override
  Json _fields() => {'step': step};
}

/// 소환 결과 연출을 닫았다 → GameState.lastSummon = null.
class AckSummonResult extends Command {
  const AckSummonResult();

  @override
  String get type => 'ackSummonResult';
}
