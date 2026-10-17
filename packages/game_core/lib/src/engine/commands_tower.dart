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
