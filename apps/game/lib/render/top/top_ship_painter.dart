import 'dart:ui';

import 'package:pirate_dot/render/paint/sprite_draw.dart';

/// 탑다운 내 배 (T2): 층 시트(tools/art/gen_topdown_ships.py) 6장을 이 순서로 겹친다 — 바탕 · 선체 · 화물 · 대포 · 돛 · 망루.
/// 부위 단계 = BattleView.shipLook (0단계는 1단계 그림). 아래에 바다 그림자(뱃머리 반대·오른쪽 아래로 비낀 어두운 실루엣).
/// 배 기준 좌표(가운데 (0,0), 뱃머리 위, 단위)로 그린다 — 부르는 쪽이 배 자리로 옮기고 진행 방향으로 돌려 둔다.
class TopShipPainter {
  TopShipPainter(this.sprites);

  final SpriteDraw sprites;

  /// 겹치는 순서 (스프라이트 키 `td:<tierId>:<layer>`).
  static const layers = ['base', 'hull', 'cargo', 'cannon', 'sail', 'crowsnest'];

  final _shadow = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0x4D0B1E3A), BlendMode.srcIn);

  /// 배 그림 프레임 크기 (단위). 그림이 없으면 null.
  Size? sizeOf(String tierId) {
    final s = sprites.sheet('td:$tierId:base');
    return s == null ? null : Size(s.frameW, s.frameH);
  }

  /// [look] = 부위 → 단계, [glowPart]가 있으면 그 층을 [glow](0~1) 만큼 흰빛으로 한 번 더.
  /// 그림이 없으면 false.
  bool paint(
    Canvas c,
    String tierId,
    Map<String, int> look, {
    bool flash = false,
    String? glowPart,
    double glow = 0,
  }) {
    final size = sizeOf(tierId);
    if (size == null) return false;
    final base = sprites.sheet('td:$tierId:base')!;
    // 그림자: 바탕 실루엣을 오른쪽 아래로 3·4단위
    c.drawImageRect(
      base.image,
      Rect.fromLTWH(0, 0, base.frameW, base.frameH),
      Rect.fromLTWH(-size.width / 2 + 3, -size.height / 2 + 4, size.width, size.height),
      _shadow,
    );
    for (final layer in layers) {
      final key = 'td:$tierId:$layer';
      final sheet = sprites.sheet(key);
      if (sheet == null) continue;
      final stage = look[layer] ?? 0;
      final frame = layer == 'base' ? 0 : ((stage < 1 ? 1 : stage) - 1).clamp(0, sheet.frames - 1);
      sprites.draw(c, key, 0, 0, frame: frame, w: size.width, h: size.height, flash: flash);
      if (glowPart == layer && glow > 0) {
        sprites.draw(c, key, 0, 0, frame: frame, w: size.width, h: size.height, flash: true, alpha: glow);
      }
    }
    return true;
  }
}
