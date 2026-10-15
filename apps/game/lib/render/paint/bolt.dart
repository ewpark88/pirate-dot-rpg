import 'dart:ui';

/// 궁극기 번개 표시 (매끈한 다각형, [u] = 1dp, 왼쪽 위 ([x], [y])): [fill] 몸 + [edge] 테두리. [p]는 그리는 쪽 붓(채우기로 돌려놓는다).
void drawBolt(Canvas c, Paint p, double x, double y, double u, int fill, int edge) {
  final path = Path()
    ..moveTo(x + 6 * u, y)
    ..lineTo(x + 1 * u, y + 8 * u)
    ..lineTo(x + 5 * u, y + 8 * u)
    ..lineTo(x + 3 * u, y + 14 * u)
    ..lineTo(x + 9.5 * u, y + 5.5 * u)
    ..lineTo(x + 5.5 * u, y + 5.5 * u)
    ..lineTo(x + 8 * u, y)
    ..close();
  p.color = Color(fill);
  c.drawPath(path, p);
  p
    ..style = PaintingStyle.stroke
    ..strokeWidth = u
    ..color = Color(edge);
  c.drawPath(path, p);
  p.style = PaintingStyle.fill;
}
