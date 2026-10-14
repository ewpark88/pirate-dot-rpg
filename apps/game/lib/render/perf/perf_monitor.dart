import 'dart:typed_data';

import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 최근 프레임 시간으로 fps·p50·p95·최대를 잰다 (실기기 60fps 관문, docs/specs/render-perf.md).
///
/// 고정 링 버퍼라 프레임마다 할당이 없다. 백분위는 읽을 때만 정렬한다(운영자 패널·요약이 가끔 읽음).
class PerfMonitor {
  PerfMonitor({this.window = 120, this.slowMs = 33}) : _ring = Float64List(window), _sorted = Float64List(window);

  final int window;

  /// 이보다 긴 프레임을 "느린 프레임"으로 센다.
  final double slowMs;

  final Float64List _ring;
  final Float64List _sorted;
  int _next = 0;
  int _count = 0;
  int _slowSinceSummary = 0;
  bool _dirty = true;
  double _p50 = 0;
  double _p95 = 0;
  double _max = 0;
  double _sum = 0;

  int get count => _count;

  void add(double frameMs) {
    if (_count == window) {
      _sum -= _ring[_next];
    } else {
      _count++;
    }
    _ring[_next] = frameMs;
    _sum += frameMs;
    _next = (_next + 1) % window;
    if (frameMs > slowMs) _slowSinceSummary++;
    _dirty = true;
  }

  double get p50 {
    _compute();
    return _p50;
  }

  double get p95 {
    _compute();
    return _p95;
  }

  double get maxMs {
    _compute();
    return _max;
  }

  /// 창 안 평균 프레임 시간으로 본 fps.
  double get fps => _count == 0 || _sum <= 0 ? 0 : 1000 * _count / _sum;

  void _compute() {
    if (!_dirty || _count == 0) return;
    for (var i = 0; i < _count; i++) {
      _sorted[i] = _ring[i];
    }
    final view = Float64List.sublistView(_sorted, 0, _count)..sort();
    _p50 = _rank(view, 0.5);
    _p95 = _rank(view, 0.95);
    _max = view[_count - 1];
    _dirty = false;
  }

  /// nearest-rank 백분위.
  static double _rank(Float64List sorted, double p) {
    var k = (p * sorted.length).ceil() - 1;
    if (k < 0) k = 0;
    return sorted[k];
  }

  /// 콘솔 요약 한 줄. 느린 프레임 수는 지난 요약 이후로 센다.
  String takeSummary(SceneStats stats) {
    final line =
        '[perf] fps=${fps.toStringAsFixed(1)} p50=${p50.toStringAsFixed(1)}ms '
        'p95=${p95.toStringAsFixed(1)}ms max=${maxMs.toStringAsFixed(1)}ms slow=$_slowSinceSummary '
        'fx=${stats.effects} num=${stats.numbers} proj=${stats.projectiles} coins=${stats.coins}';
    _slowSinceSummary = 0;
    return line;
  }
}
