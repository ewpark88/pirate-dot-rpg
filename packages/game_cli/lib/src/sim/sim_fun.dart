import 'package:game_cli/src/sim/sim_content.dart';
import 'package:game_cli/src/sim/sim_result.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 재미 장치 계측 (돌발 이벤트·즉석 도전, platform-fun-*.md 수용 기준의 sim 몫).
/// 가상 플레이어는 황금 물고기의 `meta.sim.fishTapRatio`만큼 탭하고, 유리병은 고르지 않는다(10초 뒤 첫 쪽지).
class SimFun {
  SimFun(this.t);

  final GameTables t;

  /// 탑·러시(장면 콘텐츠) — 같은 사건을 본다.
  late final content = SimContent(t);
  BigNum killGold = BigNum.zero;
  BigNum eventGold = BigNum.zero;
  int challenges = 0;
  int challengeWins = 0;

  /// 피버: 발동 수, 피버 중 처치 골드.
  int fevers = 0;

  /// 화물칸이 가득 차 버린 골드.
  BigNum overflowGold = BigNum.zero;
  BigNum feverGold = BigNum.zero;

  /// 이번 틱 사건을 보고, 필요하면 탭 명령을 넣는다.
  void observe(GameEvent e, CoreEngine engine) {
    content.observe(e, engine);
    switch (e) {
      case Kill(:final gold):
        killGold = killGold + gold;
        if (feverOn(engine.state)) feverGold = feverGold + gold;
      case FeverStarted():
        fevers++;
      case GoldOverflow(:final lost):
        overflowGold = overflowGold + lost;
      case GoldfishCaught(:final gold):
        eventGold = eventGold + gold;
      case BottlePicked(:final reward) when reward.startsWith('gold:'):
        eventGold = eventGold + BigNum.parse(reward.substring('gold:'.length));
      case SeaEventStarted(id: 'goldfish'):
        final fish = [...?engine.state.battle?.enemies.where((x) => x.eventKind == 'goldfish')];
        final n = (fish.length * t.meta.raw.obj('sim').number('fishTapRatio')).round();
        for (final f in fish.take(n)) {
          engine.enqueue(TapSeaEvent(f.id));
        }
      case ChallengeStarted():
        challenges++;
      case ChallengeEnded(:final success):
        if (success) challengeWins++;
      default:
    }
  }

  /// 돌발 이벤트 골드 ÷ 처치 골드 (%).
  double? get eventGoldPct => killGold.isZero ? null : (eventGold / killGold).toDouble() * 100;

  /// 피버 중 처치 골드 ÷ 처치 골드 (%).
  double? get feverGoldPct => killGold.isZero ? null : (feverGold / killGold).toDouble() * 100;

  /// 넘친 골드 ÷ 처치 골드 (%).
  double? get overflowPct => killGold.isZero ? null : (overflowGold / killGold).toDouble() * 100;

  /// 끝난 도전 중 성공 (%).
  double? get challengeWinPct => challenges == 0 ? null : challengeWins / challenges * 100;

  /// 결과에 재미·콘텐츠 계측을 옮긴다([online] = 접속 시간, 피버 간격용).
  void fill(SimResult r, Duration online) => r
    ..eventGoldPct = eventGoldPct
    ..challengeWinPct = challengeWinPct
    ..feverIntervalMin = fevers == 0 ? null : online.inSeconds / Duration.secondsPerMinute / fevers
    ..feverGoldPct = feverGoldPct
    ..overflowPct = overflowPct
    ..towerFloorSec = SimContent.median(content.towerFloorSec)
    ..towerRunMin = SimContent.median(content.towerRunMin)
    ..rushSec = SimContent.median(content.rushSec);
}
