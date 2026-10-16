part of 'commands.dart';

// 현상금 사냥 명령 (docs/specs/platform-content-bounty.md 5절, 요청 platform-bounty-b0b2.md B0).

/// 현상금 전투 시작: 오늘 보스(일요일은 아무 보스)·열린 단계·티켓 ≥ 1일 때만. 티켓 −1.
class StartBounty extends Command {
  const StartBounty(this.bossId, this.tier);

  final String bossId;
  final int tier;

  @override
  String get type => 'startBounty';

  @override
  Json _fields() => {'bossId': bossId, 'tier': tier};
}

/// 깬 최고 단계로 [count]장 소탕 (티켓이 모자라면 있는 만큼, 깬 단계가 없으면 무시).
class SweepBounty extends Command {
  const SweepBounty(this.bossId, this.count);

  final String bossId;
  final int count;

  @override
  String get type => 'sweepBounty';

  @override
  Json _fields() => {'bossId': bossId, 'count': count};
}

/// 현상금 전투 도중 후퇴 = 실패(티켓 반환).
class RetreatBounty extends Command {
  const RetreatBounty();

  @override
  String get type => 'retreatBounty';
}

/// 운영자: 현상금 티켓 수 지정.
class OpSetBountyTickets extends OperatorCommand {
  const OpSetBountyTickets(this.count);

  final int count;

  @override
  String get type => 'op.setBountyTickets';

  @override
  Json _fields() => {'count': count};
}

/// 운영자: 요일 고정 1(월)~7(일), null = 기기 날짜. 세이브에 남지 않는다(EconomySystem이 들고 있음).
class OpSetWeekday extends OperatorCommand {
  const OpSetWeekday([this.weekday]);

  final int? weekday;

  @override
  String get type => 'op.setWeekday';

  @override
  Json _fields() => {'weekday': weekday};
}
