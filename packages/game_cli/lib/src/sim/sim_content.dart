import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 새 콘텐츠 계측(심연의 탑·보스 러시, S5 엔진 — 3자 균형 경계에 '탑 층당 초·한 판 분'을 붙이려고, 사용자 상시 지시).
/// 가상 플레이어는 파를 잡을 때마다 장면이 비어 있으면 탑 → 러시 순으로 도전권을 바로 쓴다.
class SimContent {
  SimContent(this.t);

  final GameTables t;
  final towerFloorSec = <double>[];
  final towerRunMin = <double>[];
  final rushSec = <double>[];
  int? _towerStart;
  int? _floorStart;

  double get _secPerTick => t.waves.tickMs / Duration.millisecondsPerSecond;

  void observe(GameEvent e, CoreEngine engine) {
    switch (e) {
      case WaveCleared():
        final s = engine.state;
        if (sceneBusy(s)) return;
        if (canStartTower(s, t)) {
          engine.enqueue(const StartTower());
        } else if (canStartRush(s, t)) {
          engine.enqueue(const StartRush());
        }
      case TowerStarted(:final tick):
        _towerStart = tick;
        _floorStart = tick;
      case TowerFloorCleared(:final tick):
        if (_floorStart != null) towerFloorSec.add((tick - _floorStart!) * _secPerTick);
        _floorStart = tick;
      case TowerEnded(:final tick):
        if (_towerStart != null) towerRunMin.add((tick - _towerStart!) * _secPerTick / Duration.secondsPerMinute);
        _towerStart = _floorStart = null;
      case RushEnded(:final ticks):
        rushSec.add(ticks * _secPerTick);
      default:
    }
  }

  static double? median(List<double> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    return s[s.length ~/ 2];
  }
}
