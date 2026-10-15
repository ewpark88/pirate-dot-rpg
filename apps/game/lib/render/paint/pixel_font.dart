import 'dart:ui';

import 'package:pirate_dot/render/paint/pixel_glyphs.dart';

/// 글자가 바뀔 때만 Picture로 다시 굽는 도트 글자 (데미지 숫자·콤보 배너·HUD, render-quality-v1 규칙 4).
/// 매 프레임 글자 픽셀마다 사각형을 그리지 않게 한다.
class PixelText {
  Picture? _picture;
  String _text = '';
  int _color = 0;
  int _scale = 0;

  /// 다시 구운 횟수 (테스트용).
  int renders = 0;

  String get text => _text;
  double get width => pixelTextWidth(_text, scale: _scale);

  /// [text]·[argb]·[scale]이 그대로면 아무것도 하지 않는다.
  void set(String text, int argb, int scale) {
    if (_picture != null && text == _text && argb == _color && scale == _scale) return;
    _picture?.dispose();
    final rec = PictureRecorder();
    drawPixelText(Canvas(rec), text, 0, 0, argb, scale: scale);
    _picture = rec.endRecording();
    _text = text;
    _color = argb;
    _scale = scale;
    renders++;
  }

  /// 왼쪽 위 (x, y)에 그린다(정수 픽셀).
  void draw(Canvas c, double x, double y) {
    final p = _picture;
    if (p == null) return;
    c
      ..save()
      ..translate(x.roundToDouble(), y.roundToDouble())
      ..drawPicture(p)
      ..restore();
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}
