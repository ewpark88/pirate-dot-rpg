import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';

part 'hd_opening_parts.dart';

/// 오프닝 5컷 배경(S4 요청 — ui/story/opening_screen.dart의 _CutArt 바탕): HD 카툰 결 코드 그림, 천천히 움직인다.
/// 0 바다·지도(새벽 바다·해·갈매기·떠 있는 보물지도) · 1 옥토와 낡은 배(잔잔한 바다 위 기운 작은 배 — 옥토 그림은 UI가 위에)
/// · 2 괴물/보스(폭풍 밤바다·번개·솟는 촉수 실루엣·멀리 빛나는 눈) · 3 동료(노을 갑판·깃발 줄·반짝이)
/// · 4 출항(노을 수평선으로 돛 가득 편 배·빛 길). 컷 그림(캐릭터·보스 초상)은 UI가 가운데 위에 얹는다.
class HdOpeningBackdrop extends StatefulWidget {
  const HdOpeningBackdrop({required this.cut, this.animate = true, super.key});

  /// 0~4.
  final int cut;

  /// false면 멈춘 그림(애니메이션 줄이기·골든).
  final bool animate;

  @override
  State<HdOpeningBackdrop> createState() => _HdOpeningBackdropState();
}

class _HdOpeningBackdropState extends State<HdOpeningBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    if (widget.animate) unawaited(_loop.repeat());
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _OpeningPainter(widget.cut, _loop), size: Size.infinite),
  );
}

class _OpeningPainter extends CustomPainter {
  _OpeningPainter(this.cut, this.loop) : super(repaint: loop);

  final int cut;
  final Animation<double> loop;
  final _k = HdKit();
  final _p = Paint()..isAntiAlias = true;

  double get _t => loop.value * 6000; // ms

  @override
  void paint(Canvas c, Size s) {
    _k.begin(s.shortestSide * 0.06);
    switch (cut) {
      case 0:
        _sky(c, s, const [Color(0xFF2A3A7A), Color(0xFFF08AA0), Color(0xFFFFD08A)]);
        _sun(c, Offset(s.width * 0.7, s.height * 0.42), s.width * 0.12, const Color(0xFFFFE7A0));
        _clouds(c, s, const Color(0xFFFFF4F0));
        _sea(c, s, s.height * 0.5, const Color(0xFF3A8FD8), const Color(0xFF1A4A8A));
        _gulls(c, s);
        _map(c, Offset(s.width * 0.5, s.height * 0.72), s.width * 0.26);
      case 1:
        _sky(c, s, const [Color(0xFF6AB8F0), Color(0xFFA8E0FF), Color(0xFFE8F8FF)]);
        _clouds(c, s, const Color(0xFFFFFFFF));
        _sea(c, s, s.height * 0.55, const Color(0xFF4AA8E8), const Color(0xFF1E5AA0));
        _oldBoat(c, Offset(s.width * 0.5, s.height * 0.62), s.width * 0.34);
      case 2:
        _sky(c, s, const [Color(0xFF120A24), Color(0xFF2A1A4A), Color(0xFF4A2A5A)]);
        _lightning(c, s);
        _sea(c, s, s.height * 0.58, const Color(0xFF2A3A6A), const Color(0xFF0E1630));
        _tentacles(c, s);
      case 3:
        _sky(c, s, const [Color(0xFFFF8A5A), Color(0xFFFFB86A), Color(0xFFFFE0A0)]);
        _deck(c, s);
        _bunting(c, s);
        _sparkles(c, s, const Color(0xFFFFF4C0));
      default:
        _sky(c, s, const [Color(0xFF3A2A6A), Color(0xFFE06A7A), Color(0xFFFFB45A)]);
        _sun(c, Offset(s.width * 0.5, s.height * 0.5), s.width * 0.18, const Color(0xFFFFD45A));
        _sea(c, s, s.height * 0.52, const Color(0xFFE0806A), const Color(0xFF3A2A6A));
        _lightPath(c, s);
        _sailShip(c, Offset(s.width * 0.5, s.height * 0.6), s.width * 0.3);
        _sparkles(c, s, const Color(0xFFFFF0B0));
    }
  }

  void _sky(Canvas c, Size s, List<Color> colors) {
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(Offset.zero & s);
    c.drawRect(Offset.zero & s, _p);
    _p.shader = null;
  }

  void _sun(Canvas c, Offset at, double r, Color color) {
    final pulse = 1 + 0.03 * math.sin(_t / 600);
    for (var i = 3; i >= 1; i--) {
      _p.color = color.withValues(alpha: 0.12 * i);
      c.drawCircle(at, r * (1 + i * 0.35) * pulse, _p);
    }
    _p.color = color;
    c.drawCircle(at, r, _p);
  }

  void _clouds(Canvas c, Size s, Color color) {
    final drift = (_t / 6000) * s.width * 0.1;
    for (final (x, y, w) in const [(0.15, 0.14, 0.3), (0.62, 0.1, 0.24), (0.85, 0.25, 0.2), (0.3, 0.3, 0.18)]) {
      final at = Offset((x * s.width + drift) % (s.width * 1.2) - s.width * 0.1, y * s.height);
      final cw = w * s.width;
      final p = Path()
        ..addOval(Rect.fromCenter(center: at, width: cw, height: cw * 0.35))
        ..addOval(Rect.fromCenter(center: at + Offset(-cw * 0.22, -cw * 0.1), width: cw * 0.45, height: cw * 0.38))
        ..addOval(Rect.fromCenter(center: at + Offset(cw * 0.15, -cw * 0.14), width: cw * 0.5, height: cw * 0.42));
      _p.color = color.withValues(alpha: 0.9);
      c.drawPath(p, _p);
    }
  }

  /// 겹친 카툰 물결 띠 3단(외곽선) + 반짝 대시.
  void _sea(Canvas c, Size s, double top, Color light, Color dark) {
    for (var band = 0; band < 3; band++) {
      final y = top + band * (s.height - top) * 0.28;
      final col = Color.lerp(light, dark, band / 2.5)!;
      final p = Path()..moveTo(0, s.height);
      final amp = s.height * 0.012 * (band + 1);
      final phase = _t / (900 - band * 150) + band;
      for (var x = 0.0; x <= s.width + 1; x += s.width / 24) {
        p.lineTo(x, y + math.sin(x / s.width * 8 + phase) * amp);
      }
      p
        ..lineTo(s.width, s.height)
        ..close();
      _p.color = col;
      c.drawPath(p, _p);
      _k.ink
        ..color = const Color(0x661A1424)
        ..strokeWidth = s.shortestSide * 0.006;
      c.drawPath(p, _k.ink);
    }
    _k.ink.color = HdKit.inkColor;
    _p.color = const Color(0x99FFFFFF);
    for (var i = 0; i < 14; i++) {
      final x = (i * 97.3 + _t / 40) % s.width;
      final y = top + (i * 53.1) % (s.height - top) * 0.9;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: s.width * 0.05, height: 3),
          const Radius.circular(2),
        ),
        _p,
      );
    }
  }

  void _gulls(Canvas c, Size s) {
    final w = s.shortestSide * 0.006;
    _k.ink.strokeWidth = w;
    for (var i = 0; i < 4; i++) {
      final x = ((i * 0.23 + _t / 12000) % 1.1) * s.width;
      final y = s.height * (0.18 + i * 0.05) + math.sin(_t / 300 + i) * 4;
      final flap = math.sin(_t / 150 + i) * s.width * 0.01;
      final p = Path()
        ..moveTo(x - s.width * 0.03, y + flap)
        ..quadraticBezierTo(x - s.width * 0.015, y - s.width * 0.012, x, y)
        ..quadraticBezierTo(x + s.width * 0.015, y - s.width * 0.012, x + s.width * 0.03, y + flap);
      c.drawPath(p, _k.ink);
    }
  }

  @override
  bool shouldRepaint(covariant _OpeningPainter old) => old.cut != cut;
}
