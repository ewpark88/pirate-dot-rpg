import 'package:game_cli/src/sim/sim_result.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 초반 체감 계측 (사용자 피드백 2026-10-17 #21·#4·#8): 환영 선원 받은 시점, 첫 배 외형 변화, 처음 10분의 외형 변화·피버 수.
/// 금고 피로(같은 날): 첫 회차 스테이지 [cargoStages]에 처음 닿은 순간 '빈 금고가 가득 차는 분' = 용량 ÷ 초당 골드 추정.
class SimEarly {
  SimEarly(this.t, this.result);

  final GameTables t;
  final SimResult result;
  static const cargoStages = [10, 20, 40, 80];
  static const window = Duration(minutes: 10);

  void observe(GameEvent e, Duration elapsed, GameState s) {
    switch (e) {
      case StageAdvanced(:final stage) when s.progress.rebirths == 0 && cargoStages.contains(stage):
        final perSec = goldPerSecEstimate(s, t, offlineFleet(s, t));
        if (!perSec.isZero) {
          result.cargoFillMin[stage] ??= (goldCapacity(s, t) / perSec).toDouble() / Duration.secondsPerMinute;
        }
      case CardGranted(source: 'starter'):
        result.welcomeCrew ??= elapsed;
      case ShipLookChanged():
        result.firstLookChange ??= elapsed;
        if (elapsed <= window) result.lookChanges10Min++;
      case FeverStarted():
        result.firstFever ??= elapsed;
        if (elapsed <= window) result.fevers10Min++;
      default:
    }
  }
}
