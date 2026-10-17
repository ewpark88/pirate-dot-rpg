import 'package:flutter/painting.dart';

/// 탑다운 큰 글자(빠른 항해 컷인·새 동료 등): 굵은 남색 테두리 + 흰 글자에 색 그늘, 한글 글꼴. 글자·크기·색별로 TextPainter를 기억한다.
class TopLabel {
  final Map<String, (TextPainter, TextPainter)> _texts = {};
  static const _gold = Color(0xFFFFD84A);
  static const _navy = Color(0xFF1B2A4A);

  /// 캐시한 글자 수(메모리 진단·시험).
  int get cached => _texts.length;

  void clear() {
    for (final (a, b) in _texts.values) {
      a.dispose();
      b.dispose();
    }
    _texts.clear();
  }

  void draw(Canvas c, String s, Offset center, double size, {double alpha = 1, Color color = _gold}) {
    final key = '$s|$size|${color.toARGB32()}';
    final pair = _texts.putIfAbsent(key, () {
      if (_texts.length > 40) clear(); // 글자가 계속 바뀌는 TOTAL 등 — 버릴 때 문단(네이티브)을 바로 놓는다(S5 PSS 누수)
      TextPainter make(TextStyle style) => TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final base = TextStyle(fontFamily: 'Jua', fontFamilyFallback: const ['GowunDodumSymbols'], fontSize: size);
      // 두 겹: 굵은 남색 테두리 + 흰 바탕에 색 그늘 — 황금 바다·띠 어디서도 읽힌다.
      return (
        make(
          base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = _navy,
          ),
        ),
        make(
          base.copyWith(
            color: const Color(0xFFFFFFFF),
            shadows: [Shadow(color: color, offset: Offset(0, size * 0.06))],
          ),
        ),
      );
    });
    final (outline, fill) = pair;
    final at = center - Offset(fill.width / 2, fill.height / 2);
    // 글자 크기만큼의 레이어(화면 전체 레이어는 텍스처가 튄다 — S5 gfx)
    final bounds = (at & Size(fill.width, fill.height)).inflate(fill.height * 0.3);
    final veil = Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0, 1));
    if (alpha < 1) c.saveLayer(bounds, veil);
    outline.paint(c, at);
    fill.paint(c, at);
    if (alpha < 1) c.restore();
  }
}
