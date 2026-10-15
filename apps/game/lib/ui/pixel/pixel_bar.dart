import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 도트 진행 막대: 윤곽 1칸 + 어두운 바탕 + 채움 (캔버스 함성 게이지와 같은 모양). 1칸 = [pixelUnit].
class PixelBar extends StatelessWidget {
  const PixelBar({required this.value, this.fill = PixelPalette.danger, this.dots = 5, super.key});

  /// 0~1.
  final double value;
  final Color fill;

  /// 막대 높이(칸).
  final int dots;

  @override
  Widget build(BuildContext context) {
    final u = pixelUnit(context);
    return SizedBox(
      height: dots * u,
      child: CustomPaint(painter: _BarPainter(value.clamp(0, 1), fill, u), size: Size.infinite),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter(this.value, this.fill, this.unit);

  final double value;
  final Color fill;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = (size.width / unit).floor();
    final h = (size.height / unit).floor();
    if (w < 3 || h < 3) return;
    void rect(int x, int y, int rw, int rh, Color c) =>
        canvas.drawRect(Rect.fromLTWH(x * unit, y * unit, rw * unit, rh * unit), Paint()..color = c);
    rect(0, 0, w, h, PixelPalette.outline);
    final inner = w - 2;
    final filled = (inner * value).round();
    if (filled > 0) rect(1, 1, filled, h - 2, fill);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.value != value || old.fill != fill || old.unit != unit;
}
