import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 9-slice 도트 프레임 (그림 파일 없이 그린다, 스펙 ui-quality-v1 규칙 4).
/// 바깥부터: 윤곽 1칸 · 테두리 [borderDots]칸 · (위·왼쪽) 하이라이트 1칸 / (아래·오른쪽) 그늘 1칸 · 바탕.
/// 네 모서리는 1칸 깎는다. [dropShadow]면 맨 아래 1칸은 윤곽색 그림자(버튼이 떠 보이게). 1칸 = [pixelUnit].
class PixelFrame extends StatelessWidget {
  const PixelFrame({
    required this.child,
    this.fill = PixelPalette.navy,
    this.border = PixelPalette.border,
    this.highlight = PixelPalette.highlight,
    this.shade,
    this.shadeDots = 1,
    this.borderDots = 1,
    this.dropShadow = false,
    this.padding = 3,
    super.key,
  });

  final Widget child;
  final Color fill;
  final Color border;
  final Color? highlight;

  /// 아래·오른쪽 안쪽 그늘 (null이면 없음).
  final Color? shade;

  /// 그늘 두께(칸).
  final int shadeDots;

  /// 테두리 두께(칸).
  final int borderDots;

  /// 맨 아래 1칸 그림자.
  final bool dropShadow;

  /// 안쪽 여백(칸 수). 프레임 두께(3칸)를 포함한다.
  final int padding;

  @override
  Widget build(BuildContext context) {
    final u = pixelUnit(context);
    return CustomPaint(
      painter: PixelFramePainter(
        unit: u,
        fill: fill,
        border: border,
        highlight: highlight,
        shade: shade,
        shadeDots: shadeDots,
        borderDots: borderDots,
        dropShadow: dropShadow,
      ),
      child: Padding(padding: EdgeInsets.all(u * padding), child: child),
    );
  }
}

class PixelFramePainter extends CustomPainter {
  const PixelFramePainter({
    required this.unit,
    required this.fill,
    required this.border,
    this.highlight,
    this.shade,
    this.shadeDots = 1,
    this.borderDots = 1,
    this.dropShadow = false,
  });

  final double unit;
  final Color fill;
  final Color border;
  final Color? highlight;
  final Color? shade;
  final int shadeDots;
  final int borderDots;
  final bool dropShadow;

  @override
  void paint(Canvas canvas, Size size) {
    // 칸 단위 크기 (남는 조각은 버린다 — 칸 경계가 실제 픽셀에 맞게).
    final w = (size.width / unit).floor();
    final full = (size.height / unit).floor();
    final h = dropShadow ? full - 1 : full;
    final b = borderDots;
    if (w < 2 * b + 2 || h < 2 * b + 2) return;
    void rect(int x, int y, int rw, int rh, Color c) =>
        canvas.drawRect(Rect.fromLTWH(x * unit, y * unit, rw * unit, rh * unit), Paint()..color = c);

    // 그림자 (윤곽 아래 1칸, 모서리 깎음)
    if (dropShadow) rect(1, h, w - 2, 1, PixelPalette.outline);
    // 윤곽 (모서리 1칸 깎음)
    rect(1, 0, w - 2, 1, PixelPalette.outline);
    rect(1, h - 1, w - 2, 1, PixelPalette.outline);
    rect(0, 1, 1, h - 2, PixelPalette.outline);
    rect(w - 1, 1, 1, h - 2, PixelPalette.outline);
    // 테두리 + 바탕
    rect(1, 1, w - 2, h - 2, border);
    final i = 1 + b;
    rect(i, i, w - 2 * i, h - 2 * i, fill);
    // 아래·오른쪽 그늘, 위·왼쪽 하이라이트 (빛이 왼쪽 위에서)
    final sh = shade;
    if (sh != null) {
      final d = shadeDots;
      rect(i, h - i - d, w - 2 * i, d, sh);
      rect(w - i - d, i, d, h - 2 * i, sh);
    }
    final hl = highlight;
    if (hl != null) {
      rect(i, i, w - 2 * i, 1, hl);
      rect(i, i, 1, h - 2 * i, hl);
    }
  }

  @override
  bool shouldRepaint(PixelFramePainter old) =>
      old.unit != unit ||
      old.fill != fill ||
      old.border != border ||
      old.highlight != highlight ||
      old.shade != shade ||
      old.shadeDots != shadeDots ||
      old.borderDots != borderDots ||
      old.dropShadow != dropShadow;
}
