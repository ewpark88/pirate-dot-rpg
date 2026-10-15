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
  // BigNum.format 접미사·소수점 (T, aa…zz). 'x'는 위 콤보 글자를 그대로 쓴다.
  '.': '000000000000010',
  'T': '111010010010010',
  'a': '000011101101011',
  'b': '100110101101110',
  'c': '000011100100011',
  'd': '001011101101011',
  'e': '000010111100011',
  'f': '011100110100100',
  'g': '000011101011110',
  'h': '100110101101101',
  'i': '010000010010010',
  'j': '001000001101010',
  'k': '100101110101101',
  'l': '110010010010011',
  'm': '000110111101101',
  'n': '000110101101101',
  'o': '000010101101010',
  'p': '000110101110100',
  'q': '000011101011001',
  'r': '000011100100100',
  's': '000011110011110',
  't': '010111010010001',
  'u': '000101101101011',
  'v': '000101101101010',
  'w': '000101101111111',
  'y': '000101101011110',
  'z': '000111001010111',
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
