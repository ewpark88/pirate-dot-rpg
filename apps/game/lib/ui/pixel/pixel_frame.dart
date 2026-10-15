import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 9-slice 도트 프레임 (그림 파일 없이 그린다, 스펙 ui-quality-v1 규칙 4).
/// 바깥부터: 윤곽 1칸 · 테두리 1칸 · (위·왼쪽) 하이라이트 1칸 · 바탕. 네 모서리는 1칸 깎는다. 1칸 = [pixelUnit].
class PixelFrame extends StatelessWidget {
  const PixelFrame({
    required this.child,
    this.fill = PixelPalette.navy,
    this.border = PixelPalette.border,
    this.highlight = PixelPalette.highlight,
    this.padding = 3,
    super.key,
  });

  final Widget child;
  final Color fill;
  final Color border;
  final Color? highlight;

  /// 안쪽 여백(칸 수). 프레임 두께(3칸)를 포함한다.
  final int padding;

  @override
  Widget build(BuildContext context) {
    final u = pixelUnit(context);
    return CustomPaint(
      painter: PixelFramePainter(unit: u, fill: fill, border: border, highlight: highlight),
      child: Padding(padding: EdgeInsets.all(u * padding), child: child),
    );
  }
}

class PixelFramePainter extends CustomPainter {
  const PixelFramePainter({required this.unit, required this.fill, required this.border, this.highlight});

  final double unit;
  final Color fill;
  final Color border;
  final Color? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    // 칸 단위 크기 (남는 조각은 버린다 — 칸 경계가 실제 픽셀에 맞게).
    final w = (size.width / unit).floor();
    final h = (size.height / unit).floor();
    if (w < 4 || h < 4) return;
    void rect(int x, int y, int rw, int rh, Color c) =>
        canvas.drawRect(Rect.fromLTWH(x * unit, y * unit, rw * unit, rh * unit), Paint()..color = c);

    // 윤곽 (모서리 1칸 깎음)
    rect(1, 0, w - 2, 1, PixelPalette.outline);
    rect(1, h - 1, w - 2, 1, PixelPalette.outline);
    rect(0, 1, 1, h - 2, PixelPalette.outline);
    rect(w - 1, 1, 1, h - 2, PixelPalette.outline);
    // 테두리 + 바탕
    rect(1, 1, w - 2, h - 2, border);
    rect(2, 2, w - 4, h - 4, fill);
    // 위·왼쪽 하이라이트 (빛이 왼쪽 위에서)
    final hl = highlight;
    if (hl != null) {
      rect(2, 2, w - 4, 1, hl);
      rect(2, 2, 1, h - 4, hl);
    }
  }

  @override
  bool shouldRepaint(PixelFramePainter old) =>
      old.unit != unit || old.fill != fill || old.border != border || old.highlight != highlight;
}
