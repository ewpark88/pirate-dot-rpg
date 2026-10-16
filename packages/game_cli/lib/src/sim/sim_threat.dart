import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 위협 계측 (사용자 신고 2026-10-16: '아무리 맞아도 배 체력이 거의 안 준다').
/// - 벽(보스 실패 스테이지)에서 선원 0명일 때 침몰 시간: 배 HP ÷ (그 파의 적 전부가 붙어 때리는 초당 피해).
/// - 파밍 파 한 번에 깎인 배 체력 비율(파 안 최저 hpRatio — 회복은 파 사이).
/// - 파밍 파 처리 시간.
class SimThreat {
  SimThreat(this.t);

  final GameTables t;
  final sinkSec = <double>[];
  final farmWaveDamage = <double>[];
  double _minRatio = 1;

  void observe(GameEvent e, CoreEngine engine) {
    final s = engine.state;
    switch (e) {
      case ShipDamaged(:final hpRatio):
        if (hpRatio < _minRatio) _minRatio = hpRatio;
      case WaveCleared():
        if (s.progress.farming) farmWaveDamage.add(1 - _minRatio);
        _minRatio = 1;
      case BossFailed(:final stage):
        final w = t.waves;
        final perSec =
            w.attackBase * math.pow(w.attackGrowth, stage - 1) * w.mobPoolAt(stage) / w.field.contactIntervalSec;
        final hp = s.battle?.shipHpMax.toDouble() ?? 0;
        if (hp > 0) sinkSec.add(hp / perSec);
        _minRatio = 1;
      default:
    }
  }

  /// 파밍 파당 깎인 배 체력 중앙값(%).
  double? get farmWaveDamagePct {
    final m = median(farmWaveDamage);
    return m == null ? null : m * 100;
  }

  static double? median(List<double> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    return s[s.length ~/ 2];
  }
}
