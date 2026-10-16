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

  /// 보스전 한 번에 깎인 배 체력(보스 행동 v2 목표 25~45%, S5).
  final bossFightDamage = <double>[];
  double _bossMin = 1;

  /// 환생 뒤 첫 벽: 첫 보스 실패 스테이지 ÷ 환생 전 최고 (사용자 신고 '환생 뒤 강화 없이 너무 멀리 감' — 목표 0.5~0.6).
  final rebirthWallRatio = <double>[];
  int? _bestBeforeRebirth;

  /// 보스 첫 도전 성공(첫 회차): 보통 스테이지 / 해역 보스(10단위) — 사용자 '너무 쉽다' 목표 70~85% / 30~50%.
  final _tried = <int>{};
  int normalTries = 0;
  int normalWins = 0;
  int wallTries = 0;
  int wallWins = 0;

  void _firstTry(GameState s, int stage, {required bool won}) {
    if (s.progress.rebirths > 0 || !_tried.add(stage)) return;
    final wall = stage % t.meta.raw.obj('sim').integer('wallEvery') == 0;
    if (wall) {
      wallTries++;
      if (won) wallWins++;
    } else {
      normalTries++;
      if (won) normalWins++;
    }
  }

  double? get bossFirstWinPct => normalTries == 0 ? null : normalWins / normalTries * 100;
  double? get wallFirstWinPct => wallTries == 0 ? null : wallWins / wallTries * 100;

  void observe(GameEvent e, CoreEngine engine) {
    final s = engine.state;
    switch (e) {
      case ShipDamaged(:final hpRatio):
        if (hpRatio < _minRatio) _minRatio = hpRatio;
        if (s.battle?.bossActive == true && hpRatio < _bossMin) _bossMin = hpRatio;
      case WaveCleared():
        if (s.progress.farming) farmWaveDamage.add(1 - _minRatio);
        _minRatio = 1;
      case BossCleared(:final stage):
        _firstTry(s, stage, won: true);
        bossFightDamage.add(1 - _bossMin);
        _bossMin = 1;
      case RebirthDone():
        _bestBeforeRebirth = s.progress.bestStage;
      case BossFailed(:final stage):
        _firstTry(s, stage, won: false);
        bossFightDamage.add(1 - _bossMin);
        _bossMin = 1;
        final before = _bestBeforeRebirth;
        if (before != null) {
          rebirthWallRatio.add(stage / before);
          _bestBeforeRebirth = null;
        }
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
