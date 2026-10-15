import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 진행 막대 (스킨 r1: 둥근 알약 `SkinBar`). 이름과 인자는 도트 시절 그대로 — [dots]는 굵기 단계.
class PixelBar extends StatelessWidget {
  const PixelBar({required this.value, this.fill = PixelPalette.danger, this.dots = 5, super.key});

  /// 0~1.
  final double value;
  final Color fill;

  /// 굵기 단계 (5 = 보통 10dp).
  final int dots;

  @override
  Widget build(BuildContext context) => SkinBar(value: value, color: fill, height: dots * 2.0);
}
