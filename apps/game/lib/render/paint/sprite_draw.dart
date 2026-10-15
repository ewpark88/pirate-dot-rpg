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
  static const _underwaterRgb = 0x0B2A44;
  ColorFilter _underwater = _tint(0.45);
  double _underwaterAlpha = 0.45;

  static ColorFilter _tint(double a) =>
      ColorFilter.mode(Color(((a * 0xFF).round() << 24) | _underwaterRgb), BlendMode.srcATop);

  double get underwaterAlpha => _underwaterAlpha;

  /// 수중 적 색조 세기 (해역마다 다름). 바뀔 때만 필터를 새로 만든다.
  set underwaterAlpha(double a) {
    if (a == _underwaterAlpha) return;
    _underwaterAlpha = a;
    _underwater = _tint(a);
  }

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

  final _smooth = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.medium;

  /// 매끈한 그림(Pirate Busters 무기·폭발 부품) — 크기 [w]×[h], 가운데 ([cx],[cy]), [angle] 라디안 회전, 반투명.
  /// 도트 그림과 달리 부드럽게 줄인다. 뱅크에 없으면 false.
  bool drawSmooth(
    Canvas c,
    String key,
    double cx,
    double cy,
    double w,
    double h, {
    double angle = 0,
    double alpha = 1,
  }) {
    final s = sheet(key);
    if (s == null || alpha <= 0) return false;
    _smooth.color = Color.fromRGBO(0, 0, 0, alpha);
    c
      ..save()
      ..translate(cx, cy);
    if (angle != 0) c.rotate(angle);
    c
      ..drawImageRect(
        s.image,
        Rect.fromLTWH(0, 0, s.frameW, s.frameH),
        Rect.fromLTWH(-w / 2, -h / 2, w, h),
        _smooth,
      )
      ..restore();
    return true;
  }
}
