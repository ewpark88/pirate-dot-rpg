import 'dart:math' as math;
import 'dart:ui';

/// 배 스킨 v3 장식 (사용자 #8 '모으는 재미' — S1: 색만 바꾸면 작게 볼 때 같아 보인다, 실루엣·장식이 달라야 한다).
/// 탑다운 배 층 위·아래에 코드로 그리는 장식과 입자. 배 기준 좌표(뱃머리 위, 프레임 size 가운데 원점), 단위 = 배 도트.
/// king 금관 뱃머리·해골 깃발·금 테 / ghostship 찢어진 돛 구멍·초록 유령불 / frost 쇄빙 날·고드름·눈송이 /
/// lava 철갑판 테·굴뚝 불꽃 / fairy 나비 날개·조개 돛·반짝 / festival 깃발 줄·풍선 / abyss 둥근 돔·잠망경·물방울.
class SkinDecor {
  final _fill = Paint()..isAntiAlias = false;
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  final _path = Path();

  static const ids = {'king', 'ghostship', 'frost', 'lava', 'fairy', 'festival', 'abyss'};

  /// 유령선은 몸이 반투명.
  static double alphaOf(String? skin) => skin == 'ghostship' ? 0.78 : 1;

  /// 배 층보다 먼저(아래): 날개·돔 그림자 등.
  void under(Canvas c, String skin, Size size, double now) {
    final hw = size.width * 0.3;
    const mid = 0.0;
    switch (skin) {
      case 'fairy':
        // 나비 날개 양옆(분홍·하늘 반투명, 천천히 퍼덕)
        final flap = 0.85 + 0.15 * math.sin(now / 160);
        for (final s in const [-1.0, 1.0]) {
          _fill.color = const Color(0xAAFF9ACF);
          c.drawOval(
            Rect.fromCenter(center: Offset(s * (hw + 9 * flap), mid - 6), width: 16 * flap, height: 20),
            _fill,
          );
          _fill.color = const Color(0xAA9AE6FF);
          c.drawOval(
            Rect.fromCenter(center: Offset(s * (hw + 7 * flap), mid + 10), width: 12 * flap, height: 14),
            _fill,
          );
          _line
            ..strokeWidth = 1
            ..color = const Color(0xCCFFFFFF);
          c.drawOval(
            Rect.fromCenter(center: Offset(s * (hw + 9 * flap), mid - 6), width: 16 * flap, height: 20),
            _line,
          );
        }
      case 'abyss':
        // 둥근 동체 그림자(잠수함 실루엣)
        _fill.color = const Color(0x55101C30);
        c.drawOval(
          Rect.fromCenter(center: const Offset(0, mid + 4), width: hw * 2.6, height: size.height * 0.92),
          _fill,
        );
      case 'lava':
        // 선체 밖 열기 아지랑이
        _fill.color = Color.fromRGBO(255, 120, 40, 0.18 + 0.08 * math.sin(now / 200));
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: hw * 2.8, height: size.height * 0.95), _fill);
    }
  }

  /// 배 층 다음(위): 장식 + 입자.
  void over(Canvas c, String skin, Size size, double now) {
    final h = size.height;
    final hw = size.width * 0.3;
    final bow = -h / 2 + 3;
    final stern = h / 2 - 6;
    double mast(double f) => -h / 2 + f * h;
    switch (skin) {
      case 'king':
        // 금관 뱃머리 장식
        _fill.color = const Color(0xFFFFD24A);
        for (var i = -2; i <= 2; i++) {
          _path
            ..reset()
            ..moveTo(i * 2.0 - 1, bow + 4)
            ..lineTo(i * 2.0, bow - 1 - (i == 0 ? 2 : 0))
            ..lineTo(i * 2.0 + 1, bow + 4)
            ..close();
          c.drawPath(_path, _fill);
        }
        c.drawRect(Rect.fromLTWH(-5, bow + 3, 10, 2), _fill);
        _fill.color = const Color(0xFFE0479E);
        c.drawRect(Rect.fromLTWH(-0.5, bow + 3, 1.5, 1.5), _fill);
        // 금 테 양옆
        _line
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFFD24A);
        for (final s in const [-1.0, 1.0]) {
          c.drawLine(Offset(s * hw, bow + 14), Offset(s * hw, stern - 4), _line);
        }
        _skullFlag(c, Offset(0, mast(0.45) - 10));
      case 'ghostship':
        // 찢어진 돛 구멍(짙은 톱니) + 초록 유령불 입자
        _fill.color = const Color(0xAA182226);
        for (final f in const [0.27, 0.48, 0.66]) {
          final y = mast(f);
          _path
            ..reset()
            ..moveTo(-6, y)
            ..lineTo(-3, y + 3)
            ..lineTo(0, y + 1)
            ..lineTo(3, y + 4)
            ..lineTo(6, y)
            ..close();
          c.drawPath(_path, _fill);
        }
        for (var i = 0; i < 6; i++) {
          final a = now / 900 + i * math.pi / 3;
          final p = Offset(math.cos(a) * (hw + 10), math.sin(a) * h * 0.42);
          final fl = 0.6 + 0.4 * math.sin(now / 120 + i);
          _fill.color = Color.fromRGBO(120, 255, 190, 0.35 * fl);
          c.drawCircle(p, 4, _fill);
          _fill.color = Color.fromRGBO(200, 255, 230, 0.9 * fl);
          c.drawCircle(p, 1.6, _fill);
        }
      case 'frost':
        // 뱃머리 쇄빙 날(희푸른 쐐기) + 선체 옆 고드름 + 눈송이
        _fill.color = const Color(0xFFDDF4FF);
        _path
          ..reset()
          ..moveTo(-6, bow + 8)
          ..lineTo(0, bow - 6)
          ..lineTo(6, bow + 8)
          ..close();
        c.drawPath(_path, _fill);
        _line
          ..strokeWidth = 1
          ..color = const Color(0xFF6EC8FF);
        c.drawPath(_path, _line);
        _fill.color = const Color(0xFFBFE8FF);
        for (final s in const [-1.0, 1.0]) {
          for (var k = 0; k < 5; k++) {
            final y = bow + 18 + k * (stern - bow - 22) / 4;
            _path
              ..reset()
              ..moveTo(s * hw, y)
              ..lineTo(s * (hw + 3.5), y + 1)
              ..lineTo(s * hw, y + 3)
              ..close();
            c.drawPath(_path, _fill);
          }
        }
        _snow(c, size, now);
      case 'lava':
        // 철갑판 테(짙은 철판 + 리벳) + 고물 굴뚝 불꽃
        _line
          ..strokeWidth = 2
          ..color = const Color(0xFF3A3436);
        for (final s in const [-1.0, 1.0]) {
          c.drawLine(Offset(s * hw, bow + 10), Offset(s * hw, stern - 2), _line);
        }
        _fill.color = const Color(0xFFB8B0B4);
        for (final s in const [-1.0, 1.0]) {
          for (var k = 0; k < 6; k++) {
            c.drawRect(Rect.fromLTWH(s * hw - 0.5, bow + 12 + k * (stern - bow - 16) / 5, 1, 1), _fill);
          }
        }
        final chim = Offset(0, stern - 8);
        _fill.color = const Color(0xFF2A2426);
        c.drawRect(Rect.fromCenter(center: chim, width: 5, height: 6), _fill);
        for (var i = 0; i < 5; i++) {
          final t = ((now / 500) + i / 5) % 1;
          _fill.color = Color.lerp(const Color(0xFFFFE27A), const Color(0x00FF4A1A), t)!;
          c.drawCircle(chim + Offset(math.sin(i * 2.0 + now / 200) * 2 * t, -4 - 14 * t), 2.6 * (1 - t) + 0.6, _fill);
        }
      case 'fairy':
        // 조개 돛 무늬(부채꼴 줄) + 반짝 입자
        _line
          ..strokeWidth = 1
          ..color = const Color(0xCCFFFFFF);
        for (final f in const [0.27, 0.48]) {
          final y = mast(f);
          for (var k = -2; k <= 2; k++) {
            c.drawLine(Offset(0, y + 4), Offset(k * 3.0, y - 2), _line);
          }
        }
        for (var i = 0; i < 6; i++) {
          final tw = math.sin(now / 150 + i * 1.7);
          if (tw < 0.3) continue;
          final p = Offset(((i * 37) % 21 - 10) * hw / 9, ((i * 53) % 41 - 20) * h / 44);
          _fill.color = Color.fromRGBO(255, 240, 255, tw);
          c
            ..drawRect(Rect.fromCenter(center: p, width: 4, height: 1.2), _fill)
            ..drawRect(Rect.fromCenter(center: p, width: 1.2, height: 4), _fill);
        }
      case 'festival':
        // 돛대 사이 깃발 줄(색 삼각 깃발) + 고물 풍선
        const colors = [0xFFFF5A5A, 0xFFFFE24A, 0xFF5AD85A, 0xFF4AB8FF, 0xFFB98CFF];
        final a = Offset(0, bow + 6);
        final b = Offset(0, stern - 4);
        for (final s in const [-1.0, 1.0]) {
          _line
            ..strokeWidth = 0.8
            ..color = const Color(0xFF1B1726);
          final mid = Offset(s * (hw + 4), 0);
          c
            ..drawLine(a, mid, _line)
            ..drawLine(mid, b, _line);
          for (var k = 1; k < 8; k++) {
            final t = k / 8;
            final p = t < 0.5 ? Offset.lerp(a, mid, t * 2)! : Offset.lerp(mid, b, (t - 0.5) * 2)!;
            _fill.color = Color(colors[k % colors.length]);
            _path
              ..reset()
              ..moveTo(p.dx - 1.5, p.dy)
              ..lineTo(p.dx + 1.5, p.dy)
              ..lineTo(p.dx, p.dy + 3)
              ..close();
            c.drawPath(_path, _fill);
          }
        }
        for (var i = 0; i < 3; i++) {
          final p = Offset((i - 1) * 6.0, stern + 6 + math.sin(now / 300 + i) * 1.5);
          _line
            ..strokeWidth = 0.6
            ..color = const Color(0xFFFFFFFF);
          c.drawLine(Offset((i - 1) * 2.0, stern - 2), p, _line);
          _fill.color = Color(colors[i * 2 % colors.length]);
          c.drawOval(Rect.fromCenter(center: p, width: 5, height: 6), _fill);
          _fill.color = const Color(0x88FFFFFF);
          c.drawRect(Rect.fromLTWH(p.dx - 1.5, p.dy - 2, 1, 1), _fill);
        }
      case 'abyss':
        // 둥근 유리 돔 + 잠망경 + 떠오르는 물방울
        _fill.color = const Color(0x6648E0FF);
        c.drawOval(Rect.fromCenter(center: Offset(0, mast(0.45)), width: 12, height: 16), _fill);
        _line
          ..strokeWidth = 1
          ..color = const Color(0xFF6AF8FF);
        c.drawOval(Rect.fromCenter(center: Offset(0, mast(0.45)), width: 12, height: 16), _line);
        _fill.color = const Color(0xFF2E4A6A);
        c.drawRect(Rect.fromCenter(center: Offset(0, mast(0.2)), width: 2, height: 8), _fill);
        c.drawRect(Rect.fromLTWH(-1, mast(0.2) - 5, 4, 2), _fill);
        for (var i = 0; i < 6; i++) {
          final t = ((now / 900) + i / 6) % 1;
          final p = Offset(((i * 29) % 17 - 8) * hw / 8, stern - (stern - bow) * t);
          _line
            ..strokeWidth = 0.8
            ..color = Color.fromRGBO(200, 250, 255, 0.8 * (1 - t));
          c.drawCircle(p, 1 + 1.5 * t, _line);
        }
    }
  }

  void _skullFlag(Canvas c, Offset at) {
    const rows = ['kkkkkk', 'kwwwwk', 'kwkkwk', 'kwwwwk', 'kkwwkk', 'kkkkkk'];
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        _fill.color = rows[y][x] == 'w' ? const Color(0xFFF6F1E6) : const Color(0xFF1B1726);
        c.drawRect(Rect.fromLTWH(at.dx + x - 3, at.dy + y - 3, 1, 1), _fill);
      }
    }
  }

  void _snow(Canvas c, Size size, double now) {
    for (var i = 0; i < 6; i++) {
      final t = ((now / 1400) + i / 6) % 1;
      final p = Offset(((i * 41) % 23 - 11) * size.width / 26, -size.height / 2 + size.height * t);
      _fill.color = Color.fromRGBO(255, 255, 255, 0.9 * (1 - t));
      c.drawRect(Rect.fromCenter(center: p, width: 1.5, height: 1.5), _fill);
    }
  }
}
