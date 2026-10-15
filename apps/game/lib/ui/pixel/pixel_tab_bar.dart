import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 하단 탭 한 칸.
class PixelTabItem extends StatelessWidget {
  const PixelTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
    this.dotKey,
    super.key,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// ‘지금 할 수 있는 일’ 빨간 점 (탭마다 하나).
  final bool badge;

  /// 빨간 점의 키 (보일 때만 — 테스트용).
  final Key? dotKey;

  @override
  Widget build(BuildContext context) => Semantics(
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
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 고른 탭: 하늘색 알약 안에 그림.
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? Skin.skyDeep : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: PixelDot(
                  show: badge,
                  dotKey: dotKey,
                  child: Opacity(opacity: selected ? 1 : 0.7, child: icon),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Skin.text(13, color: selected ? Skin.primaryEdge : Skin.sub),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 하단 탭 막대 (스킨 r1): 화면 아래 떠 있는 흰 둥근 판, 고른 탭은 하늘색 알약.
class PixelTabBar extends StatelessWidget {
  const PixelTabBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      // 화면 아래 떠 있는 흰 둥근 판 (스킨 r1).
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Skin.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Skin.shadowColor, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [for (final c in children) Expanded(child: c)]),
        ),
      ),
    ),
  );
}
