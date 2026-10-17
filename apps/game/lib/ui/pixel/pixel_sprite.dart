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
    // HD 아이콘(디자인 개편 ②): 한 장·정사각, 부드럽게 줄인다(도트처럼 최근접 확대하지 않음). 화면 배율 그림은 Flutter가 고른다.
    if (asset.startsWith(UiSprites.hdDir)) {
      // fit이 없으면 원본(1x 32px)보다 크게 그리지 않는다(scaleDown) — 도크처럼 큰 칸에서 작아 보이던 것(S4).
      return Image.asset(asset, width: side, height: side, fit: BoxFit.contain);
    }
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

/// UI 그림 경로. 아이콘은 HD 광택 아이콘(디자인 개편 ② 쿵푸할매 스타일, `tools/art/gen_hd_icons.py` — 1x 32 · 2.0x · 3.0x),
/// 카드 뒷면·말풍선은 도트 그대로(`tools/art/gen_ui_icons.py`).
abstract final class UiSprites {
  /// HD 아이콘 폴더 — PixelSprite가 이 경로면 부드럽게 그린다.
  static const hdDir = 'assets/ui/hd/';

  static const tabMap = '${hdDir}tab_map.png';
  static const tabShip = '${hdDir}tab_ship.png';
  static const tabCrew = '${hdDir}tab_crew.png';
  static const tabSummon = '${hdDir}tab_summon.png';

  /// 젬(HD는 한 장 — 예전 도트 3프레임 frames 인자는 무시된다).
  static const gem = '${hdDir}gem.png';
  static const coin = '${hdDir}coin.png';

  /// 등급 별.
  static const star = '${hdDir}star.png';

  static const gear = '${hdDir}gear.png';
  static const quest = '${hdDir}quest.png';
  static const tailwind = '${hdDir}tailwind.png';
  static const flag = '${hdDir}flag.png';
  static const ad = '${hdDir}ad.png';
  static const farm = '${hdDir}farm.png';
  static const lock = '${hdDir}lock.png';
  static const rebirth = '${hdDir}rebirth.png';
  static const moon = '${hdDir}moon.png';
  static const hand = '${hdDir}hand.png';
  static const bubble = 'assets/ui/bubble.png';

  /// 새 HD 아이콘: 보물상자 · 지도 조각 · 트로피 · 상점 · 우편.
  static const chest = '${hdDir}chest.png';
  static const shard = '${hdDir}shard.png';
  static const trophy = '${hdDir}trophy.png';
  static const shop = '${hdDir}shop.png';
  static const mail = '${hdDir}mail.png';

  /// 계열 아이콘(skills.json family id — lob·direct·pierce·skip·underwater·air·assault·shock·ring·cluster·laser).
  static String family(String id) => '${hdDir}fam_$id.png';

  /// 소환 카드 뒷면 32×32.
  static const cardBack = 'assets/ui/card_back.png';

  /// 체크 (받음 / 안 받음).
  static const check = '${hdDir}check.png';
  static const checkEmpty = '${hdDir}check_empty.png';

  /// 배 부위 아이콘 (`ship_parts.json` id).
  static String part(String id) => '${hdDir}part_$id.png';
}
