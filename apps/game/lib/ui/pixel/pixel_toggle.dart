import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 2상태 스위치 (스킨 r1): 둥근 홈 + 흰 동그란 손잡이. 켜짐 = 파란 홈·손잡이 오른쪽. 누르는 영역 48dp.
class PixelToggle extends StatelessWidget {
  const PixelToggle({required this.value, required this.onChanged, this.semanticLabel, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const _w = 50.0;
  static const _h = 30.0;

  @override
  Widget build(BuildContext context) {
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              width: _w,
              height: _h,
              padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: !enabled ? Skin.disabled : (value ? Skin.primaryBottom : Skin.track),
                borderRadius: BorderRadius.circular(_h / 2),
              ),
              child: Container(
                width: _h - 6,
                height: _h - 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: Skin.shadowSmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 세그먼트 (스킨 r1): 칸마다 버튼, 고른 칸은 파란 주 버튼.
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

/// 설정 같은 목록의 한 줄: 글자 + 오른쪽 위젯, 아래 얇은 구분선 (ListTile·Divider 대신).
class PixelListRow extends StatelessWidget {
  const PixelListRow({required this.title, this.leading, this.trailing, this.onTap, super.key});

  final Widget title;

  /// 왼쪽 아이콘 (설정 r2).
  final Widget? leading;
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
                if (leading case final l?) ...[l, const SizedBox(width: 12)],
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
