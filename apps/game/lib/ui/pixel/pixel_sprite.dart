import 'package:flutter/widgets.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 아트 레인 도트 그림 (`assets/ui/*.png`) 한 장. 한 점 = [pixelUnit] × [scale], 최근접 확대.
/// 가로로 프레임을 이어 붙인 그림(젬 8×8×3)은 [frames]로 나눠 첫 프레임만 보인다.
class PixelSprite extends StatelessWidget {
  const PixelSprite(this.asset, {required this.dots, this.frames = 1, this.scale = 2, super.key});

  final String asset;

  /// 프레임 한 장의 한 변(정사각, 점 수).
  final int dots;
  final int frames;
  final int scale;

  @override
  Widget build(BuildContext context) {
    final side = dots * pixelUnit(context) * scale;
    final image = Image.asset(
      asset,
      width: side * frames,
      height: side,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    );
    if (frames == 1) return image;
    return SizedBox(
      width: side,
      height: side,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: side * frames,
          maxWidth: side * frames,
          child: image,
        ),
      ),
    );
  }
}

/// 아트 레인 UI 그림 경로 (`tools/art/gen_ui_icons.py`).
abstract final class UiSprites {
  static const tabMap = 'assets/ui/tab_map.png';
  static const tabShip = 'assets/ui/tab_ship.png';
  static const tabCrew = 'assets/ui/tab_crew.png';
  static const tabSummon = 'assets/ui/tab_summon.png';

  /// 젬 8×8 × 3프레임.
  static const gem = 'assets/ui/gem.png';

  /// 금화 16×16.
  static const coin = 'assets/ui/coin.png';

  /// 등급 별 16×16.
  static const star = 'assets/ui/star.png';

  /// 배 부위 아이콘 16×16 (`ship_parts.json` id).
  static String part(String id) => 'assets/ui/part_$id.png';
}
