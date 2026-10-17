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
              // 고른 탭: 노란 네모 칸 안에 그림 (k1).
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Skin.ribbonTop, Skin.goldBottom],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: Skin.outline, width: 2) : null,
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
                style: Skin.outlined(
                  14,
                  color: selected ? const Color(0xFFFFFFFF) : const Color(0xFFC9CAF0),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 하단 탭 막대 (스킨 k1): 짙은 남색 판 + 굵은 외곽선, 고른 탭만 노란 칸.
class PixelTabBar extends StatelessWidget {
  const PixelTabBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Skin.navyPanel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
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
