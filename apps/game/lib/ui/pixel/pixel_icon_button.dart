import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';

/// 그림 아이콘 크기 목표(dp) — 실기기에서 24~28dp (layout-v2-brief 1).
const kIconTargetDp = 26.0;

/// 16px 그림을 실제 픽셀 정수배로, [targetDp]에 가장 가까운 크기(dp).
double pixelIconSize(double devicePixelRatio, {int dots = 16, double targetDp = kIconTargetDp}) {
  final scale = (targetDp * devicePixelRatio / dots).round().clamp(1, 1 << 10);
  return scale * dots / devicePixelRatio;
}

/// 틀 없는 그림 버튼: 그림은 [pixelIconSize], 누르는 영역은 48dp. 누르면 1칸 내려앉고 어두워진다.
/// [semanticLabel]은 화면 낭독·길게 누르기 설명으로 쓴다.
class PixelIconButton extends StatefulWidget {
  const PixelIconButton({
    required this.asset,
    required this.semanticLabel,
    required this.onPressed,
    this.trailing,
    super.key,
  });

  final String asset;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// 그림 오른쪽 작은 글자 (광고 이득 ‘×2’ 등).
  final Widget? trailing;

  @override
  State<PixelIconButton> createState() => _PixelIconButtonState();
}

class _PixelIconButtonState extends State<PixelIconButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = pixelIconSize(dpr);
    final enabled = widget.onPressed != null;
    return Tooltip(
      message: widget.semanticLabel,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: enabled ? () => setState(() => _down = false) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
            child: Center(
              widthFactor: 1,
              child: Transform.translate(
                offset: Offset(0, _down ? pixelUnit(context) : 0),
                child: Opacity(
                  opacity: !enabled ? 0.4 : (_down ? 0.7 : 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        widget.asset,
                        width: size,
                        height: size,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.none,
                      ),
                      if (widget.trailing case final t?) ...[
                        const SizedBox(width: 2),
                        DefaultTextStyle.merge(
                          style: const TextStyle(color: PixelPalette.gold, fontWeight: FontWeight.bold),
                          child: t,
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
  }
}
