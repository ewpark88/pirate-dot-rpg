part of 'commands.dart';

// 심연의 탑 명령 (docs/specs/platform-content-v2.md 4절, 요청 platform-tower.md 2절).

/// 탑 도전: 열림(환생 ≥ 1 또는 최고 스테이지 ≥ meta.tower.unlockStage)·도전권 ≥ 1·현상금/탑 진행 중 아님. 도전권 −1, 1층부터.
class StartTower extends Command {
  const StartTower();

  @override
  String get type => 'startTower';
}

/// 소탕: 깬 최고 층 × sweepRatio 층의 상자 보상 즉시(첫 클리어 보상 없음). 도전권 −1.
class SweepTower extends Command {
  const SweepTower();

  @override
  String get type => 'sweepTower';
}

/// 탑 도중 그만두기 — 도달 층까지 기록·상자.
class RetreatTower extends Command {
  const RetreatTower();

  @override
  String get type => 'retreatTower';
}

/// 보스 러시 도전(platform-boss-rush): 열림(탑과 같음)·도전 ≥ 1·장면 모드 진행 중 아님. 도전 −1, 첫 보스부터.
class StartRush extends Command {
  const StartRush();

  @override
  String get type => 'startRush';
}

/// 보스 러시 도중 그만두기 — 잡은 수만큼 보상.
class RetreatRush extends Command {
  const RetreatRush();

  @override
  String get type => 'retreatRush';
}

/// 요일 던전 도전(platform-weekday-dungeon): 오늘 묶음·열린 단계(깬 단계 + 1까지)·도전 ≥ 1·그 날 계열 선원 보유·장면 모드 아님.
class StartDungeon extends Command {
  const StartDungeon(this.step);

  final int step;

  @override
  String get type => 'startDungeon';

  @override
  Json _fields() => {'step': step};
}

/// 요일 던전 소탕: 오늘 묶음에서 깬 단계 [step] 이하의 보상을 바로(전투 없음). 도전 −1.
class SweepDungeon extends Command {
  const SweepDungeon(this.step);

  final int step;

  @override
  String get type => 'sweepDungeon';

  @override
  Json _fields() => {'step': step};
}

/// 요일 던전 도중 그만두기 = 실패(도전 돌려줌).
class RetreatDungeon extends Command {
  const RetreatDungeon();

  @override
  String get type => 'retreatDungeon';
}

/// 장면 모드(탑·러시·요일 던전) 명령 type — commands.dart 300줄 규칙으로 여기서 읽는다.
const _sceneTypes = {
  'startTower',
  'sweepTower',
  'retreatTower',
  'startRush',
  'retreatRush',
  'startDungeon',
  'sweepDungeon',
  'retreatDungeon',
};

Command _sceneCommandFromJson(String type, Json j) => switch (type) {
  'startTower' => const StartTower(),
  'sweepTower' => const SweepTower(),
  'retreatTower' => const RetreatTower(),
  'startRush' => const StartRush(),
  'retreatRush' => const RetreatRush(),
  'startDungeon' => StartDungeon(j['step'] as int),
  'sweepDungeon' => SweepDungeon(j['step'] as int),
  _ => const RetreatDungeon(),
};
