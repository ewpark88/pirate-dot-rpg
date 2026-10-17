import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// 쿵푸할매식 테두리 숫자(디자인 개편 공용 부품): 흰·금·빨강·초록 글씨 + 굵은 검은 테 + 아래 그림자.
/// 그림은 tools/art/gen_outline_digits.py가 만든 아틀라스(assets/ui/digits/outline_digits.png @1x·2x·3x + .json, 좌표는 1x).
/// UI(OutlineText 위젯, S4)와 렌더 피해 숫자(S3)가 같이 쓴다 — 아틀라스에 없는 글자는 건너뛴다(공백은 반 칸).
const outlineDigitsAsset = 'assets/ui/digits/outline_digits';

/// 아틀라스 배치(json) — 그림 없이도 폭을 잰다(테스트·레이아웃).
class OutlineDigitsLayout {
  OutlineDigitsLayout.fromJson(Map<String, dynamic> j)
    : width = (j['width'] as num).toDouble(),
      cellHeight = (j['cellHeight'] as num).toDouble(),
      fontSize = (j['fontSize'] as num? ?? j['cellHeight'] as num).toDouble(),
      baseline = (j['baseline'] as num).toDouble(),
      rows = {for (final e in (j['colors'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()},
      glyphs = {
        for (final e in (j['glyphs'] as Map<String, dynamic>).entries)
          e.key: (
            x: ((e.value as Map<String, dynamic>)['x'] as num).toDouble(),
            w: ((e.value as Map<String, dynamic>)['w'] as num).toDouble(),
            advance: ((e.value as Map<String, dynamic>)['advance'] as num).toDouble(),
          ),
      };

  /// 1x 아틀라스 폭(그림 배율 = 실제 폭 ÷ 이것).
  final double width;
  final double cellHeight;

  /// 칸 안 글자 크기(1x) — 글꼴 크기 s로 그리려면 칸 높이 = s × cellHeight ÷ fontSize.
  final double fontSize;

  /// 글자 크기 [size]에 맞는 칸 높이.
  double heightFor(double size) => size * cellHeight / fontSize;
  final double baseline;

  /// 색 이름(white·gold·red·green) → 그 줄의 y(1x).
  final Map<String, double> rows;
  final Map<String, ({double x, double w, double advance})> glyphs;

  double get _space => cellHeight * 0.25;

  /// [text]를 높이 [height]로 그렸을 때 폭(논리 px). 마지막 글자는 advance 대신 w.
  double measure(String text, {double? height}) {
    final k = (height ?? cellHeight) / cellHeight;
    var x = 0.0;
    var last = 0.0;
    for (final ch in text.split('')) {
      // 아틀라스 글자는 모두 한 코드 단위
      final g = glyphs[ch];
      if (g == null) {
        if (ch == ' ') (x, last) = (x + _space, 0); // paint와 같게 — 없는 글자는 그냥 건너뛴다
        continue;
      }
      x += g.advance;
      last = g.w - g.advance;
    }
    return (x + last) * k;
  }
}

/// 그림까지 읽은 아틀라스. [load]로 한 번 읽어 두고 [paint]로 그린다.
class OutlineDigits {
  OutlineDigits(this.layout, this.image) : scale = image.width / layout.width;

  final OutlineDigitsLayout layout;
  final ui.Image image;

  /// 그림 배율(1x·2x·3x 파일 중 고른 것).
  final double scale;

  /// 기기 배율 [devicePixelRatio]에 맞는 해상도 그림(AssetImage 변형 규칙)과 json을 읽는다.
  static Future<OutlineDigits> load({AssetBundle? bundle, double devicePixelRatio = 1}) async {
    final b = bundle ?? rootBundle;
    final layout = OutlineDigitsLayout.fromJson(
      jsonDecode(await b.loadString('$outlineDigitsAsset.json')) as Map<String, dynamic>,
    );
    final stream = AssetImage('$outlineDigitsAsset.png', bundle: b).resolve(
      ImageConfiguration(bundle: b, devicePixelRatio: devicePixelRatio),
    );
    final done = Completer<ui.Image>();
    late final ImageStreamListener l;
    l = ImageStreamListener(
      (info, _) {
        done.complete(info.image);
        stream.removeListener(l);
      },
      onError: (e, st) {
        done.completeError(e, st);
        stream.removeListener(l);
      },
    );
    stream.addListener(l);
    return OutlineDigits(layout, await done.future);
  }

  /// [text]를 왼쪽 위 [at]부터 높이 [height](논리 px, 기본 아틀라스 칸 높이)로 [color] 줄에서 그린다. 그린 폭을 돌려준다.
  double paint(Canvas canvas, Offset at, String text, {String color = 'white', double? height, Paint? paint}) {
    final row = layout.rows[color] ?? layout.rows.values.first;
    final k = (height ?? layout.cellHeight) / layout.cellHeight;
    final p = paint ?? (Paint()..filterQuality = FilterQuality.medium);
    var x = at.dx;
    for (final ch in text.split('')) {
      // 아틀라스 글자는 모두 한 코드 단위
      final g = layout.glyphs[ch];
      if (g == null) {
        x += ch == ' ' ? layout._space * k : 0;
        continue;
      }
      final src = Rect.fromLTWH(g.x * scale, row * scale, g.w * scale, layout.cellHeight * scale);
      canvas.drawImageRect(image, src, Rect.fromLTWH(x, at.dy, g.w * k, layout.cellHeight * k), p);
      x += g.advance * k;
    }
    return layout.measure(text, height: height);
  }
}
