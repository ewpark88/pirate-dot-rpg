import 'dart:math' as math;
import 'dart:ui';

/// HD 해역 바다 디테일(S1 — '손맛 배경 한 단계'): sea-v2(TopSeaPainter 팔레트·물결·소품) 위, 날씨(TopAtmosphere) 아래에
/// 빛 반사를 얹는다. 화면 좌표(바다 흐름 scroll만큼 아래로 흐름), 가볍게(프레임당 수십 번 그리기).
///   공통: 햇빛 일렁임 띠(넓고 옅은 물결 모양) + 반짝이는 4갈래 빛(바다 흐름과 함께 흐름)
///   coral 분홍빛 일렁임·작은 거품 고리 · storm 바람결 사선 · glacier 떠다니는 얼음 조각 · volcano 주황 불티 반짝임
///   · abyss 위에서 내려오는 빛줄기 + 청록 발광 점 · phantom 옆으로 흐르는 초록 안개
class HdSeaDetail {
  final _p = Paint()..isAntiAlias = true;
  final _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _band = Path();

  void paint(Canvas c, Rect view, double now, double scroll, String region, {bool lite = false, double fever = 0}) {
    if (fever > 0) _feverSea(c, view, now, fever, lite: lite);
    if (fever > 0.6) return; // 피버 금빛 바다엔 해역 디테일 대신 피버 빛
    final dim = 1 - fever;
    c
      ..save()
      ..clipRect(view);
    final caustic = switch (region) {
      'storm' => 0.0,
      'abyss' || 'phantom' => 0.03,
      'coral' => 0.09,
      _ => 0.07,
    };
    if (caustic > 0) {
      _caustics(
        c,
        view,
        now,
        scroll,
        region == 'coral' ? const Color(0xFFFFE0F0) : const Color(0xFFFFFFFF),
        caustic * dim,
      );
    }
    _glints(
      c,
      view,
      now,
      scroll,
      region == 'volcano' ? const Color(0xFFFFB45A) : const Color(0xFFFFFFFF),
      lite ? 7 : 14,
      dim,
    );
    switch (region) {
      case 'coral':
        _bubbles(c, view, now, scroll, dim);
      case 'storm':
        _windStreaks(c, view, now, scroll, dim);
      case 'glacier':
        _floes(c, view, scroll, dim);
      case 'abyss':
        _godRays(c, view, now, dim);
        _bioDots(c, view, now, scroll, lite ? 10 : 22, dim);
      case 'phantom':
        _mist(c, view, now, dim);
    }
    c.restore();
  }

  /// 피버 금빛 바다 v2: 배 둘레 밝은 금빛 → 가장자리 짙은 호박색(적이 노랑에 묻히지 않게) + 배에서 퍼지는 박동 고리
  /// (0.6초) + 금빛 4갈래 반짝임.
  void _feverSea(Canvas c, Rect v, double now, double f, {required bool lite}) {
    final ship = Offset(v.center.dx, v.top + v.height * 0.72);
    _p.shader = Gradient.radial(
      ship,
      v.height * 0.8,
      [
        Color.fromRGBO(255, 255, 230, 0.35 * f),
        const Color.fromRGBO(255, 210, 90, 0),
        Color.fromRGBO(190, 70, 20, 0.5 * f),
      ],
      const [0, 0.35, 1],
    );
    c.drawRect(v, _p);
    _p.shader = null;
    for (var i = 0; i < 2; i++) {
      final u = (now / 600 + i * 0.5) % 1;
      _stroke
        ..strokeWidth = 3 * (1 - u) + 0.5
        ..color = Color.fromRGBO(255, 250, 210, 0.65 * (1 - u) * f);
      c.drawOval(
        Rect.fromCenter(center: ship, width: v.width * (0.2 + 1.1 * u), height: v.width * (0.14 + 0.8 * u)),
        _stroke,
      );
    }
    _glints(c, v, now, now * 0.12, const Color(0xFFFFFBE0), lite ? 8 : 18, f);
  }

  /// 햇빛 일렁임: 화면을 가로지르는 넓은 물결 띠 3개가 천천히 흐르고 출렁인다.
  void _caustics(Canvas c, Rect v, double now, double scroll, Color color, double a) {
    for (var i = 0; i < 3; i++) {
      final y0 = v.top + ((i * 0.37 * v.height + scroll * 0.35) % (v.height * 1.2)) - v.height * 0.1;
      _band.reset();
      final amp = v.height * 0.025;
      for (var x = 0.0; x <= v.width + 8; x += v.width / 16) {
        final y = y0 + math.sin(x / v.width * 5 + now / 1300 + i * 2) * amp;
        x == 0 ? _band.moveTo(v.left + x, y) : _band.lineTo(v.left + x, y);
      }
      for (var x = v.width; x >= -8; x -= v.width / 16) {
        final y = y0 + v.height * 0.05 + math.sin(x / v.width * 6 + now / 1100 + i) * amp;
        _band.lineTo(v.left + x, y);
      }
      _band.close();
      _p.color = color.withValues(alpha: a * (0.7 + 0.3 * math.sin(now / 900 + i)));
      c.drawPath(_band, _p);
    }
  }

  /// 반짝임: 자리 해시로 흩어진 4갈래 빛이 깜빡이며 바다와 함께 흐른다.
  void _glints(Canvas c, Rect v, double now, double scroll, Color color, int n, double dim) {
    for (var i = 0; i < n; i++) {
      final x = v.left + (i * 97.31 % 1) * v.width;
      final y = v.top + ((i * 61.7 + scroll) % v.height);
      final tw = math.sin(now / 260 + i * 1.9);
      if (tw < 0.3) continue;
      final s = (tw - 0.3) / 0.7 * v.width * 0.012;
      _p.color = color.withValues(alpha: 0.85 * dim);
      final p = Path()
        ..moveTo(x, y - s * 2)
        ..lineTo(x + s * 0.4, y - s * 0.4)
        ..lineTo(x + s * 2, y)
        ..lineTo(x + s * 0.4, y + s * 0.4)
        ..lineTo(x, y + s * 2)
        ..lineTo(x - s * 0.4, y + s * 0.4)
        ..lineTo(x - s * 2, y)
        ..lineTo(x - s * 0.4, y - s * 0.4)
        ..close();
      c.drawPath(p, _p);
    }
  }

  void _bubbles(Canvas c, Rect v, double now, double scroll, double dim) {
    _stroke.strokeWidth = 1.2;
    for (var i = 0; i < 8; i++) {
      final u = (now / 2400 + i * 0.13) % 1;
      final x = v.left + (i * 0.123 + 0.05) % 1 * v.width;
      final y = v.top + ((i * 83.0 + scroll) % v.height) - u * 12;
      _stroke.color = Color.fromRGBO(255, 230, 245, 0.55 * (1 - u) * dim);
      c.drawCircle(Offset(x, y), 2 + 3 * u, _stroke);
    }
  }

  void _windStreaks(Canvas c, Rect v, double now, double scroll, double dim) {
    _stroke.strokeWidth = 1.4;
    for (var i = 0; i < 10; i++) {
      final x = v.left + ((i * 0.171 + now / 4000) % 1) * v.width;
      final y = v.top + ((i * 71.0 + scroll * 1.2) % v.height);
      _stroke.color = Color.fromRGBO(220, 235, 255, 0.28 * dim);
      c.drawLine(Offset(x, y), Offset(x - v.width * 0.08, y + v.width * 0.04), _stroke);
    }
  }

  /// 떠다니는 얼음 조각(흰 다각형 + 아래 하늘색 그늘 + 가는 테).
  void _floes(Canvas c, Rect v, double scroll, double dim) {
    for (var i = 0; i < 5; i++) {
      final cx = v.left + (i * 0.217 + 0.08) % 1 * v.width;
      final cy = v.top + ((i * 157.0 + scroll) % (v.height + 40)) - 20;
      final s = v.width * (0.03 + (i % 3) * 0.012);
      final p = Path()
        ..moveTo(cx - s, cy)
        ..lineTo(cx - s * 0.4, cy - s * 0.7)
        ..lineTo(cx + s * 0.8, cy - s * 0.5)
        ..lineTo(cx + s, cy + s * 0.3)
        ..lineTo(cx + s * 0.1, cy + s * 0.8)
        ..lineTo(cx - s * 0.8, cy + s * 0.5)
        ..close();
      _p.color = Color.fromRGBO(120, 190, 230, 0.5 * dim);
      c.drawPath(p.shift(const Offset(1.5, 2)), _p);
      _p.color = Color.fromRGBO(240, 252, 255, 0.92 * dim);
      c.drawPath(p, _p);
      _stroke
        ..strokeWidth = 1
        ..color = Color.fromRGBO(90, 150, 200, 0.7 * dim);
      c.drawPath(p, _stroke);
    }
  }

  void _godRays(Canvas c, Rect v, double now, double dim) {
    for (var i = 0; i < 3; i++) {
      final x = v.left + v.width * (0.2 + i * 0.3) + math.sin(now / 3000 + i) * v.width * 0.05;
      final w = v.width * 0.12;
      final p = Path()
        ..moveTo(x - w * 0.3, v.top)
        ..lineTo(x + w * 0.3, v.top)
        ..lineTo(x + w, v.bottom)
        ..lineTo(x - w, v.bottom)
        ..close();
      _p.shader = Gradient.linear(Offset(x, v.top), Offset(x, v.bottom), [
        Color.fromRGBO(150, 230, 255, 0.12 * dim * (0.7 + 0.3 * math.sin(now / 1500 + i))),
        const Color(0x0096E6FF),
      ]);
      c.drawPath(p, _p);
    }
    _p.shader = null;
  }

  void _bioDots(Canvas c, Rect v, double now, double scroll, int n, double dim) {
    for (var i = 0; i < n; i++) {
      final x = v.left + (i * 0.1373 + 0.02) % 1 * v.width;
      final y = v.top + ((i * 47.0 + scroll * 0.8) % v.height);
      final pulse = 0.5 + 0.5 * math.sin(now / 500 + i * 1.3);
      _p.color = Color.fromRGBO(90, 240, 255, 0.25 * pulse * dim);
      c.drawCircle(Offset(x, y), 4 + 2 * pulse, _p);
      _p.color = Color.fromRGBO(200, 255, 255, 0.8 * pulse * dim);
      c.drawCircle(Offset(x, y), 1.3, _p);
    }
  }

  void _mist(Canvas c, Rect v, double now, double dim) {
    for (var i = 0; i < 4; i++) {
      final x = v.left + ((i * 0.31 + now / 9000) % 1.3 - 0.15) * v.width;
      final y = v.top + v.height * (0.15 + i * 0.22);
      _p.color = Color.fromRGBO(170, 255, 200, 0.08 * dim);
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: v.width * 0.6, height: v.height * 0.08), _p);
    }
  }
}
