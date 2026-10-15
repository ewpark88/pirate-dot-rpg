import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 판 (스킨 r1): 둥근 모서리 판 + 부드러운 그림자. 테두리 색을 주면(등급 색·금색 등) 그 색 테두리를 두른다.
/// 이름과 인자는 도트 시절 그대로 — highlight·shade·dropShadow는 이제 쓰지 않는다(모양은 스킨이 정한다).
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
  final Color? shade;
  final int shadeDots;

  /// 테두리 두께 단계 (1 = 보통, 2 = 두꺼움).
  final int borderDots;
  final bool dropShadow;

  /// 안쪽 여백 단계 (도트 칸 수 시절 값 — dp로는 2배).
  final int padding;

  @override
  Widget build(BuildContext context) {
    final edge = border == PixelPalette.border ? null : Border.all(color: border, width: 1.5 * borderDots);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Skin.radiusCard),
        border: edge,
        boxShadow: Skin.shadowSmall,
      ),
      child: Padding(padding: EdgeInsets.all(2.0 * padding), child: child),
    );
  }
}
