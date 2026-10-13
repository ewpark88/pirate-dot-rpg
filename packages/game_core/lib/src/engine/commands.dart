import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:meta/meta.dart';

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
      'upgradePart' => UpgradePart(j['part'] as String, times: j['times'] as int? ?? 1),
      'summon' => Summon(count: j['count'] as int? ?? 1),
      'mergeAllCards' => const MergeAllCards(),
      'promoteCrew' => PromoteCrew(j['crewId'] as String),
      'challengeBoss' => const ChallengeBoss(),
      'triggerUltimate' => const TriggerUltimate(),
      'tapChest' => const TapChest(),
      'grantAdReward' => GrantAdReward(AdPlacement.values.byName(j['placement'] as String)),
      'claimOffline' => const ClaimOffline(),
      'claimDaily' => const ClaimDaily(),
      'claimAttendance' => const ClaimAttendance(),
      'rebirth' => const Rebirth(),
      'exchangeToken' => ExchangeToken(j['crewId'] as String),
      'setSetting' => SetSetting(j['key'] as String, j['value'] as Object),
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
  const UpgradePart(this.part, {this.times = 1});

  /// ship_parts.json의 id.
  final String part;
  final int times;

  @override
  String get type => 'upgradePart';

  @override
  Json _fields() => {'part': part, 'times': times};
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

/// 모든 해적의 합칠 수 있는 카드를 한 번에 합친다.
class MergeAllCards extends Command {
  const MergeAllCards();

  @override
  String get type => 'mergeAllCards';
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
  const GrantAdReward(this.placement);

  final AdPlacement placement;

  @override
  String get type => 'grantAdReward';

  @override
  Json _fields() => {'placement': placement.name};
}

/// 복귀 팝업에서 오프라인 보상 받기 (광고 ×2는 GrantAdReward(offline)).
class ClaimOffline extends Command {
  const ClaimOffline();

  @override
  String get type => 'claimOffline';
}

/// 일일 퀘스트 보상 받기.
class ClaimDaily extends Command {
  const ClaimDaily();

  @override
  String get type => 'claimDaily';
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
