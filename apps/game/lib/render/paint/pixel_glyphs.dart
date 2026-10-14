import 'dart:ui';

/// 기준 장면(battle_ship.gif, 팩 `tools/scene3.py`)의 3×5 도트 글리프. 렌더·UI가 같은 글자를 쓴다.
/// 값은 15자리 0/1 — 3칸 × 5줄, 왼쪽 위부터 가로로. 표에 없는 글자는 빈칸.
const pixelGlyphs = <String, String>{
  '0': '111101101101111',
  '1': '010110010010111',
  '2': '111001111100111',
  '3': '111001111001111',
  '4': '101101111001001',
  '5': '111100111001111',
  '6': '111100111101111',
  '7': '111001010010010',
  '8': '111101111101111',
  '9': '111101111001111',
  'x': '000101010101000',
  '!': '010010010000010',
  '+': '000010111010000',
  '-': '000000111000000',
  'K': '101101110101101',
  'C': '111100100100111',
  'O': '111101101101111',
  'M': '101111111101101',
  'B': '110101110101110',
  'G': '111100101101111',
};

/// 외곽선 색 (27,23,38).
const pixelOutline = 0xFF1B1726;

/// 글자 한 칸 폭 = 4 × [scale] px.
double pixelTextWidth(String text, {int scale = 1}) => text.length * 4.0 * scale;

const _outlineOffsets = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1)];

/// [text]를 왼쪽 위 ([x], [y])에 그린다: 먼저 1px 외곽선([outline], null이면 생략), 그다음 글자색 [argb].
/// 사각형을 글자 픽셀 수만큼 그리므로, 자주 바뀌지 않는 글자는 Picture로 구워 다시 쓰는 편이 좋다(렌더 `PixelText`).
void drawPixelText(
  Canvas canvas,
  String text,
  double x,
  double y,
  int argb, {
  int scale = 1,
  int? outline = pixelOutline,
}) {
  final paint = Paint()..isAntiAlias = false;
  final s = scale.toDouble();
  for (final pass in const [0, 1]) {
    if (pass == 0 && outline == null) continue;
    paint.color = Color(pass == 0 ? outline! : argb);
    var cx = x;
    for (var k = 0; k < text.length; k++) {
      final g = pixelGlyphs[text[k]];
      if (g != null) {
        for (var i = 0; i < g.length; i++) {
          if (g.codeUnitAt(i) != 0x31) continue;
          final px = cx + (i % 3) * s;
          final py = y + (i ~/ 3) * s;
          if (pass == 0) {
            for (final (ox, oy) in _outlineOffsets) {
              canvas.drawRect(Rect.fromLTWH(px + ox, py + oy, s, s), paint);
            }
          } else {
            canvas.drawRect(Rect.fromLTWH(px, py, s, s), paint);
          }
        }
      }
      cx += 4 * s;
    }
  }
}
