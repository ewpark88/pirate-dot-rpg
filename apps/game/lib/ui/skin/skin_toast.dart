import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 잠깐 뜨는 안내 (스킨 r1): 화면 아래쪽 잉크색 알약, [_show] 뒤 사라진다. 새 안내가 오면 앞의 것을 바꾼다.
const _show = Duration(milliseconds: 2200);

/// 되돌리기처럼 누를 것이 있는 안내는 조금 더 오래.
const _showWithAction = Duration(seconds: 4);

OverlayEntry? _current;

/// [action]을 주면 오른쪽에 누를 수 있는 글(예: '되돌리기')을 붙인다 — 누르면 [onAction] 후 닫힌다.
void showSkinToast(BuildContext context, String text, {String? action, VoidCallback? onAction}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: 120,
      child: IgnorePointer(
        ignoring: action == null,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (_, t, child) => Opacity(
              opacity: t.clamp(0, 1).toDouble(),
              child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                key: const Key('skin.toast'),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Skin.navyPanel.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
                  boxShadow: Skin.shadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: Skin.outlined(16, stroke: 1.2),
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        key: const Key('skin.toast.action'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          onAction?.call();
                          _current?.remove();
                          _current = null;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(action, style: Skin.text(16, color: Skin.goldTop)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _current = entry;
  overlay.insert(entry);
  Future.delayed(action == null ? _show : _showWithAction, () {
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}
