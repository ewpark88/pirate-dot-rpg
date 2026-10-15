import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';

/// 픽셀 그림을 화면 배율과 상관없이 정해진 dp 크기로 (글자 옆 작은 아이콘).
class SkinIcon extends StatelessWidget {
  const SkinIcon(this.asset, {this.size = 18, super.key});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: FittedBox(child: PixelSprite(asset, dots: 16, scale: 1)),
  );
}
