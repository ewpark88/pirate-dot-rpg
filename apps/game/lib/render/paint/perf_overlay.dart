import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'package:pirate_dot/render/perf/perf_monitor.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 측정용 오버레이 (`--dart-define=PERF_OVERLAY=true`). 전장 왼쪽 위에 fps·p95·최대·이펙트 수.
/// 화면 문구가 아니라 숫자와 영문 약어만 쓰는 디버그 표시라 ARB에 넣지 않는다.
class PerfOverlay {
  final _painter = TextPainter(textDirection: TextDirection.ltr);
  final _back = Paint()..color = const Color(0xAA000000);
  double _sinceLayoutMs = _relayoutMs;

  static const _relayoutMs = 500.0;
  static const _style = TextStyle(fontSize: 6, color: Color(0xFFFFFFFF));
  static const _pad = 2.0;

  void update(double dtMs, PerfMonitor perf, SceneStats stats) {
    _sinceLayoutMs += dtMs;
    if (_sinceLayoutMs < _relayoutMs) return;
    _sinceLayoutMs = 0;
    _painter
      ..text = TextSpan(
        text:
            'fps ${perf.fps.toStringAsFixed(0)} p95 ${perf.p95.toStringAsFixed(1)} '
            'max ${perf.maxMs.toStringAsFixed(1)} fx ${stats.effects}',
        style: _style,
      )
      ..layout();
  }

  /// 한 번이라도 숫자를 배치했는가 (측정 확인용).
  bool get hasText => _painter.text != null;

  void paint(Canvas canvas) {
    if (_painter.text == null) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, _painter.width + _pad * 2, _painter.height + _pad), _back);
    _painter.paint(canvas, const Offset(_pad, 1));
  }
}
