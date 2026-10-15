import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';

/// 2상태 도트 스위치 (Material Switch 대신): 켜짐 = 파란 홈에 손잡이 오른쪽, 꺼짐 = 남색 홈에 손잡이 왼쪽.
/// 그림은 22×11칸(한 칸 = 도트 2칸), 누르는 영역은 48dp.
class PixelToggle extends StatelessWidget {
  const PixelToggle({required this.value, required this.onChanged, this.semanticLabel, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const _w = 22;
  static const _h = 11;

  @override
  Widget build(BuildContext context) {
    // 그림 한 칸 = 도트 2칸 (작은 화면에서도 잘 보이게).
    final u = pixelUnit(context) * 2;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: CustomPaint(
              size: Size(_w * u, _h * u),
              painter: _TogglePainter(value: value, enabled: enabled, unit: u),
            ),
          ),
        ),
      ),
    );
  }
}

class _TogglePainter extends CustomPainter {
  const _TogglePainter({required this.value, required this.enabled, required this.unit});

  final bool value;
  final bool enabled;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    const w = PixelToggle._w;
    const h = PixelToggle._h;
    void rect(int x, int y, int rw, int rh, Color c) =>
        canvas.drawRect(Rect.fromLTWH(x * unit, y * unit, rw * unit, rh * unit), Paint()..color = c);

    // 홈: 윤곽(모서리 깎음) + 바탕 + 안쪽 위 그늘 1칸 (파인 느낌).
    rect(1, 0, w - 2, 1, PixelPalette.outline);
    rect(1, h - 1, w - 2, 1, PixelPalette.outline);
    rect(0, 1, 1, h - 2, PixelPalette.outline);
    rect(w - 1, 1, 1, h - 2, PixelPalette.outline);
    final track = !enabled ? PixelPalette.navyPressed : (value ? PixelPalette.action : PixelPalette.navyDark);
    rect(1, 1, w - 2, h - 2, track);
    rect(1, 1, w - 2, 1, value ? PixelPalette.actionDark : PixelPalette.outline);

    // 손잡이 9×9: 윤곽 + 밝은 바탕 + 위·왼쪽 하이라이트, 아래·오른쪽 그늘.
    const k = h - 2;
    final x = value ? w - 1 - k : 1;
    rect(x, 1, k, k, PixelPalette.outline);
    rect(x + 1, 2, k - 2, k - 2, enabled ? PixelPalette.text : PixelPalette.textDim);
    rect(x + 1, k - 1, k - 2, 1, PixelPalette.textDim);
    rect(x + k - 2, 2, 1, k - 2, PixelPalette.textDim);
  }

  @override
  bool shouldRepaint(_TogglePainter old) => old.value != value || old.enabled != enabled || old.unit != unit;
}

/// 도트 세그먼트 (Material SegmentedButton 대신): 칸마다 도트 버튼, 고른 칸은 주 버튼 색.
class PixelSegmented<T> extends StatelessWidget {
  const PixelSegmented({required this.segments, required this.selected, required this.onChanged, super.key});

  /// (값, 글자).
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, (value, label)) in segments.indexed) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: Semantics(
            selected: value == selected,
            child: PixelButton(
              key: ValueKey('segment.$value'),
              primary: value == selected,
              onPressed: onChanged == null ? null : () => onChanged!(value),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ],
    ],
  );
}

/// 설정 같은 목록의 한 줄: 글자 + 오른쪽 위젯, 아래 1칸 도트 구분선 (ListTile·Divider 대신).
class PixelListRow extends StatelessWidget {
  const PixelListRow({required this.title, this.trailing, this.onTap, super.key});

  final Widget title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = pixelUnit(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: PixelPalette.border, width: u),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: title),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
