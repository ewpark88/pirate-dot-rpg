import 'package:game_cli/src/sim/sim_result.dart';
import 'package:game_core/game_core.dart';

/// 초반 체감 계측 (사용자 피드백 2026-10-17 #21·#4·#8): 환영 선원 받은 시점, 첫 배 외형 변화, 처음 10분의 외형 변화·피버 수.
class SimEarly {
  SimEarly(this.result);

  final SimResult result;
  static const window = Duration(minutes: 10);

  void observe(GameEvent e, Duration elapsed) {
    switch (e) {
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
