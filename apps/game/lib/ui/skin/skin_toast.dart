import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 잠깐 뜨는 안내 (스킨 r1): 화면 아래쪽 잉크색 알약, [_show] 뒤 사라진다. 새 안내가 오면 앞의 것을 바꾼다.
const _show = Duration(milliseconds: 2200);

OverlayEntry? _current;

void showSkinToast(BuildContext context, String text) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: 120,
      child: IgnorePointer(
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
                  color: Skin.ink.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: Skin.shadow,
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Skin.text(16, color: Colors.white),
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
  Future.delayed(_show, () {
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}
