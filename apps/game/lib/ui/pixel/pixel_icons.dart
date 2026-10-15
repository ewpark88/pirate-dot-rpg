import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 임시 도트 아이콘 (10×10, `#` = 칠함). 아트 레인 16px 아이콘이 오면 그림으로 바꾼다(스펙 ui-quality-v1 요청 ③).
abstract final class PixelIcons {
  /// 항해 — 돛.
  static const voyage = [
    '....#.....',
    '....##....',
    '....###...',
    '....####..',
    '....#####.',
    '....#.....',
    '##########',
    '.########.',
    '..######..',
    '..........',
  ];

  /// 배 — 대포.
  static const ship = [
    '..........',
    '..........',
    '.#######..',
    '##########',
    '.#######..',
    '..#...#...',
    '.###.###..',
    '.###.###..',
    '..#...#...',
    '..........',
  ];

  /// 선원 — 사람.
  static const crew = [
    '...####...',
    '..######..',
    '..#.##.#..',
    '..######..',
    '...####...',
    '..........',
    '.########.',
    '##########',
    '##########',
    '##########',
  ];

  /// 골드 코인 (5×5).
  static const coin = ['.###.', '#####', '##.##', '#####', '.###.'];

  /// 젬 (5×5).
  static const gem = ['.###.', '#####', '#####', '.###.', '..#..'];

  /// 등급 별 (5×5).
  static const star = ['..#..', '.###.', '#####', '.###.', '.#.#.'];

  /// 소환 — 반짝임.
  static const summon = [
    '....#.....',
    '....#.....',
    '...###....',
    '#########.',
    '...###....',
    '....#..#..',
    '....#.###.',
    '.......#..',
    '..........',
    '..........',
  ];
}

/// 도트 비트맵 아이콘. 한 점 = [pixelUnit] × [scale]. 바깥 1점 윤곽은 그리지 않는다(작은 아이콘이라 뭉개짐).
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.bitmap, {this.color = PixelPalette.text, this.scale = 2, super.key});

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
