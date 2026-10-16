import 'package:game_core/game_core.dart';

/// 골드 수급 계측 (사용자 신고 2026-10-16: '돈이 너무 많이 벌린다, 강화를 늘 누를 수 있다').
/// 가상 플레이어는 decisionSec마다 강화를 살펴본다 — 그 순간 하나라도 살 수 있었는가, 산 순간 사이 간격(스테이지별).
class SimGold {
  int decisions = 0;
  int affordable = 0;
  int full = 0;
  Duration? _last;
  final gaps = <(int stage, double sec)>[];

  /// 한 번 살펴본 결과 — [bought]를 그대로 돌려준다. 간격은 첫 회차만(환생 뒤는 빠른 항해로 왜곡된다).
  int decide(int bought, Duration online, Progress p, {bool isFull = false}) {
    if (isFull) full++;
    final stage = p.rebirths == 0 ? p.stage : -1;
    decisions++;
    if (bought == 0) return 0;
    affordable++;
    final last = _last;
    if (last != null) gaps.add((stage, (online - last).inMilliseconds / Duration.millisecondsPerSecond));
    _last = online;
    return bought;
  }

  /// 화물칸(금고)이 가득 차 있던 순간의 비율(%).
  double? get fullPct => decisions == 0 ? null : full / decisions * 100;

  /// 살 수 있는 강화가 있던 순간의 비율(%).
  double? get affordablePct => decisions == 0 ? null : affordable / decisions * 100;

  /// 스테이지 [lo]~[hi]에서 강화 사이 간격 중앙값(초).
  double? gapMedian(int lo, int hi) {
    final xs = [
      for (final (s, g) in gaps)
        if (s >= lo && s <= hi) g,
    ]..sort();
    return xs.isEmpty ? null : xs[xs.length ~/ 2];
  }
}
