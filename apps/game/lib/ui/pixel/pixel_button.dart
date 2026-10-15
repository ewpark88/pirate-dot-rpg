import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';

/// 접근성 최소 크기 (48dp, Android 가이드라인).
const kMinTap = 48.0;

/// 도트 버튼: 도트 프레임(위·왼쪽 밝은 줄, 아래·오른쪽 그늘, 아래 그림자 1칸) + 글자. 누르면 1칸 내려앉고 어두워진다. 잉크 물결·그림자 없음. 최소 48dp.
/// [onPressed]가 null이면 비활성(흐린 글자·테두리).
class PixelButton extends StatefulWidget {
  const PixelButton({
    required this.onPressed,
    required this.child,
    this.primary = false,
    this.semanticLabel,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;

  /// 누르면 이득인 주 버튼(강화·소환 등) — 파란 바탕.
  final bool primary;

  /// 글자가 없는 버튼(아이콘만)의 화면 낭독 라벨.
  final String? semanticLabel;

  /// 작은 버튼: 누르는 영역은 48dp 그대로, 그림은 오른쪽 아래에 내용 크기로만 (카드 안 승급 등).
  final bool compact;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final u = pixelUnit(context);
    final enabled = widget.onPressed != null;
    final fill = !enabled
        ? PixelPalette.navyPressed
        : _down
        ? PixelPalette.navyPressed
        : widget.primary
        ? PixelPalette.action
        : PixelPalette.navy;
    final border = !enabled ? PixelPalette.border : (widget.primary ? PixelPalette.actionDark : PixelPalette.border);

    // 떠 있을 때는 맨 아래 1칸이 그림자, 누르면 그림자 자리로 1칸 내려앉는다(전체 크기는 그대로).
    final frame = Padding(
      padding: EdgeInsets.only(top: _down ? u : 0),
      child: PixelFrame(
        fill: fill,
        border: border,
        // 팔레트 명암: 위·왼쪽 밝은 줄 1칸, 아래·오른쪽 그늘 2칸.
        highlight: _down || !enabled
            ? null
            : widget.primary
            ? PixelPalette.actionLight
            : PixelPalette.highlight,
        shade: _down || !enabled ? null : (widget.primary ? PixelPalette.actionDark : PixelPalette.navyDark),
        shadeDots: 2,
        dropShadow: !_down,
        padding: widget.compact ? 3 : 4,
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: enabled ? PixelPalette.text : PixelPalette.textDim,
              fontWeight: FontWeight.bold,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: enabled ? PixelPalette.text : PixelPalette.textDim),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
          child: widget.compact ? Align(alignment: Alignment.bottomRight, child: frame) : frame,
        ),
      ),
    );
  }
}
