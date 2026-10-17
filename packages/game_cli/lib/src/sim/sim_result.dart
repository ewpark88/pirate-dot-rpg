import 'package:game_cli/src/sim/sim_cards.dart';
import 'package:game_cli/src/sim/sim_gold.dart';
import 'package:game_cli/src/sim/sim_threat.dart';
import 'package:game_core/game_core.dart';

/// 가상 플레이어 한 명의 결과. 시간은 모두 게임 시작부터의 경과(오프라인 포함).
class SimResult {
  SimResult(this.seed);

  final int seed;
  Duration played = Duration.zero;
  Duration? firstBossFail;
  int? firstBossFailStage;
  Duration? firstSummonReady;

  /// 환영 선원(meta.tutorial.welcomeCrew, 피드백 #21 — 목표 1분 안)을 받은 시점.
  Duration? welcomeCrew;
  Duration? stage10;
  Duration? stage40;

  /// 이미 보유한 선원의 등급이 처음 오른 시점 (승급·높은 등급 카드 점프 모두, 설계서 4.3.3 ‘첫 승급’).
  Duration? firstRarityUp;

  /// 튜토리얼 선원(`bossCards.starterCrew`, 옥토)의 첫 등급 상승(승급 또는 카드 점프) — 설계서 4.3.3 ‘운과 상관없이 첫 승급’.
  Duration? starterPromotion;
  Duration? firstLegendOwned;
  Duration? firstLegendPromoted;
  Duration? firstMythic;
  Duration wallMax = Duration.zero;
  int bestStage = 1;

  /// 파 처치 간격(초) 평균 — 처음 10분 / 전체. 전투 테이블 조정용(S1 요청).
  double waveSecFirst10Min = 0;
  double waveSecAll = 0;
  int summons = 0;

  /// 함포 지원 광고를 본 횟수 (`sim --boss-ad`).
  int bossAds = 0;
  int upgrades = 0;
  BigNum gold = BigNum.zero;
  int gems = 0;

  /// 마지막 10분(접속 중) 실제 초당 처치 골드와 끝 상태의 오프라인 추정치. 추정식 보정용.
  BigNum goldPerSecActual = BigNum.zero;
  BigNum goldPerSecEstimated = BigNum.zero;

  /// 끝 상태에서 오프라인 8시간 보상으로 살 수 있는 ‘가장 싼 강화’ 횟수.
  int offline8hUpgrades = 0;

  /// 환생 (스펙 economy-rebirth 규칙 8): 횟수, 첫 환생, 환생 뒤 이전 스테이지의 recoverTargetRatio까지 걸린 가장 긴 시간.
  int rebirths = 0;
  int mapPieces = 0;
  Duration? firstRebirth;
  int? firstRebirthStage;
  Duration? rebirthRecoverMax;

  /// 첫 환생 뒤 이전 최고(환생한 스테이지)를 넘을 때까지 접속 시간 (환생 v2 수용 기준 14).
  Duration? rebirthBeatBest;

  /// 첫 환생 직전 rebirthForecast.minutesRaw (환생 v2 수용 기준 13: 실제 rebirthBeatBest와 ±30%).
  double? rebirthForecastMin;

  /// 돌발 이벤트 골드 ÷ 처치 골드(%), 즉석 도전 성공률(%) — SimFun.
  double? eventGoldPct;
  double? challengeWinPct;

  /// 위협(SimThreat): 벽에서 선원 0명 침몰 초(중앙값), 파밍 파당 배 체력 피해(%, 중앙값).
  double? wallSinkSec;

  /// 피버 평균 간격(접속 분), 피버 중 처치 골드 비중(%).
  double? feverIntervalMin;
  double? feverGoldPct;

  /// 화물칸 넘친 골드 ÷ 처치 골드(%).
  double? overflowPct;

  /// 위협·난이도 계측(SimThreat): 환생 뒤 첫 벽 비율, 보스 첫 도전 성공률.
  SimThreat? threat;

  /// 골드 수급(SimGold): 살 수 있던 순간 비율, 강화 간격.
  SimGold? goldSupply;
  double? farmWaveDamagePct;

  /// 환생 뒤 회복 시간 ÷ 직전 회차가 같은 스테이지까지 걸린 시간(접속 시간)의 최댓값. 상대 기준 회복 지표.
  double? rebirthRecoverRatioMax;

  /// 환생한 스테이지들 (순서대로).
  final rebirthStages = <int>[];

  /// 환생 뒤 회복 중 연속 보스 처치 간격(초) — 빠른 항해(waves.rebirthSkip)에서 이동 시간 확인용.
  final recoverBossGaps = <double>[];

  /// 부위별 최고 외형 단계 — 첫날(24시간) 끝 / 첫 주 끝 (ShipLookChanged, 환생으로 내려갔다 다시 오른 것은 새 단계가 아님).
  final lookDay1 = <String, int>{};
  final lookWeek1 = <String, int>{};

  /// 부위별 최고 레벨 — 첫날 / 첫 주 (외형 단계 간격 조정용).
  final levelDay1 = <String, int>{};
  final levelWeek1 = <String, int>{};

  /// 회차별 카드 수입 (첫 회차가 0번, 환생할 때마다 하나씩 늘어난다).
  final cardsByRun = <RunCards>[RunCards()];
}

/// 접속 일정. [online]마다 [offline]만큼 쉰다. [offline]이 0이면 계속 접속.
/// [then]이 있으면 다음 접속은 그 일정을 따르고, 마지막 뒤에는 처음으로 돌아간다.
class SimSchedule {
  const SimSchedule({required this.online, this.offline = Duration.zero, this.then});

  /// 설계서 4.3.3 기준 하루: 20분 접속 → 8시간 오프라인 → 20분 접속 → 나머지(15시간 20분) 오프라인.
  static const daily = SimSchedule(
    online: Duration(minutes: 20),
    offline: Duration(hours: 8),
    then: SimSchedule(online: Duration(minutes: 20), offline: Duration(hours: 15, minutes: 20)),
  );

  final Duration online;
  final Duration offline;
  final SimSchedule? then;
}
