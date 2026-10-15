import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 버튼 색 종류.
enum SkinTone {
  /// 누르면 이득인 주 버튼 — 파랑.
  primary,

  /// 받기·광고 보상·일괄 합치기 — 금색.
  gold,

  /// 닫기·취소 같은 보조 — 흰색.
  plain,
}

/// 통통한 버튼 (스킨 r1): 위가 밝은 그라데이션 + 아래 진한 테두리 [Skin.buttonEdge] + 흰 안쪽 테두리.
/// 누르면 테두리만큼 내려앉으며 95%로 줄고, 놓으면 통 튀어 돌아온다(easeOutBack). 누르는 영역은 최소 48dp.
/// [onPressed]가 null이면 회색.
class SkinButton extends StatefulWidget {
  const SkinButton({
    required this.onPressed,
    required this.child,
    this.tone = SkinTone.primary,
    this.height = 48,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final SkinTone tone;
  final double height;
  final String? semanticLabel;

  @override
  State<SkinButton> createState() => _SkinButtonState();
}

class _SkinButtonState extends State<SkinButton> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  (Color, Color, Color, Color) get _colors => switch (widget.tone) {
    _ when widget.onPressed == null => (Skin.disabled, Skin.disabled, const Color(0xFFAEB9CB), Colors.white),
    SkinTone.primary => (Skin.primaryTop, Skin.primaryBottom, Skin.primaryEdge, Colors.white),
    SkinTone.gold => (Skin.goldTop, Skin.goldBottom, Skin.goldEdge, Skin.goldInk),
    SkinTone.plain => (Skin.plainTop, Skin.plainBottom, Skin.plainEdge, Skin.ink),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (top, bottom, edge, ink) = _colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _press.forward() : null,
        onTapCancel: enabled ? _press.reverse : null,
        onTapUp: enabled ? (_) => _press.reverse() : null,
        onTap: widget.onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 48, minHeight: widget.height < 48 ? 48 : widget.height),
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, child) {
              // easeOutBack은 놓을 때 0 밑으로 살짝 넘친다 — 크기만 통 튀고, 내려앉는 거리는 0~1로 자른다.
              final bounce = _t.value;
              final p = bounce.clamp(0.0, 1.0);
              return Transform.scale(
                scale: 1 - 0.05 * bounce,
                child: Padding(
                  // 눌리면 아래 테두리 자리로 내려앉는다(전체 높이는 그대로).
                  padding: EdgeInsets.only(top: Skin.buttonEdge * p),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: edge,
                      borderRadius: BorderRadius.circular(Skin.radiusButton),
                      boxShadow: p > 0.5 ? null : Skin.shadowSmall,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: Skin.buttonEdge * (1 - p)),
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [top, bottom],
                ),
                borderRadius: BorderRadius.circular(Skin.radiusButton),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: DefaultTextStyle.merge(
                    style: Skin.text(17, color: ink, weight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    child: IconTheme.merge(
                      data: IconThemeData(color: ink),
                      child: widget.child,
                    ),
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
