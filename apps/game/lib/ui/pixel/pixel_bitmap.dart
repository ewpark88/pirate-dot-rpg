import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 아트 레인 그림이 없는 작은 도트 표시 (`#` = 칠함): 화살표·꺾쇠.
abstract final class PixelBitmaps {
  /// 다음으로 (›).
  static const chevron = ['#..', '.#.', '..#', '.#.', '#..'];

  /// 승급 화살표.
  static const up = [
    '...#...',
    '..###..',
    '.#####.',
    '#######',
    '..###..',
    '..###..',
    '..###..',
  ];
}

/// 도트 비트맵. 한 점 = [pixelUnit] × [scale].
class PixelBitmap extends StatelessWidget {
  const PixelBitmap(this.bitmap, {this.color = PixelPalette.text, this.scale = 2, super.key});

  final List<String> bitmap;
  final Color color;
  final int scale;

  @override
  Widget build(BuildContext context) {
    final dot = pixelUnit(context) * scale;
    return CustomPaint(
      size: Size(bitmap.first.length * dot, bitmap.length * dot),
      painter: _BitmapPainter(bitmap, color, dot),
    );
  }
}

class _BitmapPainter extends CustomPainter {
  const _BitmapPainter(this.bitmap, this.color, this.dot);

  final List<String> bitmap;
  final Color color;
  final double dot;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 0; y < bitmap.length; y++) {
      for (var x = 0; x < bitmap[y].length; x++) {
        if (bitmap[y][x] == '#') canvas.drawRect(Rect.fromLTWH(x * dot, y * dot, dot, dot), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BitmapPainter old) => old.bitmap != bitmap || old.color != color || old.dot != dot;
}
