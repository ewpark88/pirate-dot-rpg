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
