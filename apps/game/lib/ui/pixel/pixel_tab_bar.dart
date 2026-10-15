import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';

/// 하단 탭 한 칸.
class PixelTabItem extends StatelessWidget {
  const PixelTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = pixelUnit(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTap),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: u * 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 고른 탭: 아이콘 뒤 밝은 남색 도트 판 + 위 1칸 금색 줄.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? PixelPalette.border : null,
                    border: selected
                        ? Border(
                            top: BorderSide(color: PixelPalette.gold, width: u),
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: u * 8, vertical: u * 2),
                    child: Opacity(opacity: selected ? 1 : 0.6, child: icon),
                  ),
                ),
                SizedBox(height: u * 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: selected ? PixelPalette.text : PixelPalette.textDim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 탭 막대 (Material NavigationBar 대신): 윤곽색 바탕, 위 1칸 테두리, 잉크·애니메이션 없음.
class PixelTabBar extends StatelessWidget {
  const PixelTabBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final u = pixelUnit(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PixelPalette.navyDark,
        border: Border(
          top: BorderSide(color: PixelPalette.border, width: u),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [for (final c in children) Expanded(child: c)]),
      ),
    );
  }
}
