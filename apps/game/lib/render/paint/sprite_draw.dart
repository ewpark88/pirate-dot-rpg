import 'dart:ui';

import 'package:pirate_dot/render/sprites/sprite_bank.dart';

/// 스프라이트 한 장 그리기: nearest·정수 좌표, 흰 번쩍임·물속 색조 필터, 반투명.
/// 뱅크에 없거나 꺼져 있으면 false → 그리는 쪽이 플레이스홀더를 그린다.
class SpriteDraw {
  SpriteBank? bank;

  /// 운영자 "스프라이트 끄기" (플레이스홀더와 비교).
  bool enabled = true;

  final _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  static const _flash = ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcATop);
  static const _underwater = ColorFilter.mode(Color(0x730B2A44), BlendMode.srcATop);

  /// 감속 색조 필터 (StatusPainter가 정한 색).
  ColorFilter? slowed;

  SpriteSheet? sheet(String key) {
    final b = bank;
    return enabled && b != null ? b[key] : null;
  }

  /// [cx]·[cy]를 중심으로 [frame]번 장을 그린다. [w]·[h]가 없으면 원래 크기.
  bool draw(
    Canvas c,
    String key,
    double cx,
    double cy, {
    int frame = 0,
    double? w,
    double? h,
    bool flash = false,
    bool underwater = false,
    bool isSlowed = false,
    double alpha = 1,
  }) {
    final s = sheet(key);
    if (s == null) return false;
    final fw = s.frameW;
    final fh = s.frameH;
    final dw = w ?? fw;
    final dh = h ?? fh;
    _paint
      ..colorFilter = flash ? _flash : (isSlowed ? slowed : (underwater ? _underwater : null))
      ..color = Color.fromRGBO(0, 0, 0, alpha);
    c.drawImageRect(
      s.image,
      Rect.fromLTWH(frame % s.frames * fw, 0, fw, fh),
      Rect.fromLTWH((cx - dw / 2).roundToDouble(), (cy - dh / 2).roundToDouble(), dw, dh),
      _paint,
    );
    return true;
  }
}
