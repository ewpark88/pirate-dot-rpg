import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/press_feel.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';

/// 접근성 최소 크기 (48dp, Android 가이드라인).
const kMinTap = 48.0;

/// 버튼 (스킨 r1의 통통한 버튼 `SkinButton`). 이름과 인자는 도트 시절 그대로.
/// [primary] = 초록 주 버튼, 아니면 흰 보조 버튼. [compact] = 그림은 작은 원형, 누르는 영역은 48dp(카드 안 승급 등).
class PixelButton extends StatelessWidget {
  const PixelButton({
    required this.onPressed,
    required this.child,
    this.primary = false,
    this.semanticLabel,
    this.compact = false,
    this.weight = PressWeight.light,
    super.key,
  });

  /// 큰 동작(구매·환생·소환)이면 heavy — '퉁' + medium 진동.
  final PressWeight weight;

  final VoidCallback? onPressed;
  final Widget child;
  final bool primary;
  final String? semanticLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return SkinButton(
        onPressed: onPressed,
        tone: primary ? SkinTone.primary : SkinTone.plain,
        semanticLabel: semanticLabel,
        weight: weight,
        child: child,
      );
    }
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Pressable(
        onTap: onPressed,
        weight: weight,
        // 카드 모서리 작은 버튼 — 꺼졌을 때 누름을 잡으면 아래 카드 탭(상세 열기)을 가로챈다.
        deniable: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enabled ? [Skin.primaryTop, Skin.primaryBottom] : [Skin.disabled, Skin.disabled],
                ),
                border: Border.all(color: Skin.outline, width: 2),
                boxShadow: Skin.shadowSmall,
              ),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
