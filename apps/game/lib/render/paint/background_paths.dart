import 'dart:math' as math;
import 'dart:ui';

/// 배경의 '모양은 같고 자리만 움직이는' 픽셀 묶음을 한 번 만든 Path로 (S1 절전·CPU: 배경이 프레임당 그리기 약 380번 중 대부분).
/// 구름 하나·빛줄기 하나·같은 속도 물결 줄 전체가 각각 그리기 1번이 된다. 배치(보이는 폭·줄 위치)가 바뀌면 다시 만든다.
class BackgroundPaths {
  BackgroundPaths({required this.squash, required this.waveGap, required this.waveLen});

  final double squash;
  final int waveGap;
  final double waveLen;

  final Map<double, Path> _clouds = {};
  final Map<(int, double, double), Path> _waves = {};
  final Map<(double, double), Path> _rays = {};

  /// 타원 구름 (가운데 x 0, 위아래 줄 y = −rows..rows): (x)² + (dy·squash)² < r² 인 픽셀. 그리는 쪽이 floor(cx)·cy로 옮긴다.
  Path cloud(double r) => _clouds[r] ??= () {
    final p = Path();
    final rows = (r / squash).ceil();
    for (var dy = -rows; dy <= rows; dy++) {
      final rest = r * r - (dy * squash) * (dy * squash);
      if (rest <= 0) continue;
      final hw = math.sqrt(rest);
      final left = (-hw).floor() + 1;
      final right = hw.ceil() - 1;
      if (right >= left) p.addRect(Rect.fromLTWH(left.toDouble(), dy.toDouble(), (right - left + 1).toDouble(), 1));
    }
    return p;
  }();

  /// 물결 대시 줄들 [rows] (같은 속도·색 한 묶음): x 0부터 [span]+간격까지 [waveGap]마다 길이 [waveLen]. 그리는 쪽이 흐름만큼 옮긴다.
  Path waves(int group, List<double> rows, double span) => _waves[(group, span, rows.isEmpty ? 0.0 : rows.first)] ??= () {
    final p = Path();
    for (final y in rows) {
      for (var x = 0.0; x < span + waveGap * 2; x += waveGap) {
        p.addRect(Rect.fromLTWH(x, y, waveLen, 1));
      }
    }
    return p;
  }();

  /// 깊은 바다 빛줄기 하나 ([top]~[bottom], 2도트 높이 칸이 비스듬히): 그리는 쪽이 floor(x0)로 옮긴다.
  Path ray(double top, double bottom, double width) => _rays[(top, bottom)] ??= () {
    final p = Path();
    for (var y = top; y < bottom - 1; y += 2) {
      p.addRect(Rect.fromLTWH(((y - top) * 0.35).floorToDouble(), y, width, 2));
    }
    return p;
  }();

  /// 배치가 바뀌면 물결·빛줄기를 버린다 (구름은 배치와 무관).
  void reset() {
    _waves.clear();
    _rays.clear();
  }
}
