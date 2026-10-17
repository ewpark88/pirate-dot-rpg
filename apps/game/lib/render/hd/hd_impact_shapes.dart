part of 'hd_impact.dart';

/// 계열별 착탄 모양(hd_impact.dart 300줄 한도로 나눔).
extension _ImpactShapes on HdImpact {
  /// 반투명이 바다 파랑과 섞여 회색으로 보이지 않게: 70%까지 불투명, 마지막 30%에만 사라짐.
  double _late(double u) => u < 0.7 ? 1 : (1 - (u - 0.7) / 0.3).clamp(0.0, 1.0);

  double _ease(double t) => 1 - (1 - t) * (1 - t) * (1 - t);
  Color _a(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));

  /// 폭발: 굵은 링 충격파 + 불꽃 꽃잎 6장(외곽선) + 둥근 연기.
  void _lob(Canvas c, _Hit h, double r, double t, {required bool lite}) {
    final e = _ease(t);
    _stroke
      ..strokeWidth = r * 0.18 * (1 - t)
      ..color = _a(h.color, 0.9 * (1 - t));
    c.drawCircle(Offset.zero, r * (0.3 + 0.8 * e), _stroke);
    if (t < 0.55) {
      final u = t / 0.55;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        final d = r * 0.35 * _ease(u);
        final p = Path()
          ..moveTo(math.cos(a - 0.35) * d, math.sin(a - 0.35) * d)
          ..quadraticBezierTo(
            math.cos(a) * (d + r * 0.95),
            math.sin(a) * (d + r * 0.95),
            math.cos(a + 0.35) * d,
            math.sin(a + 0.35) * d,
          )
          ..close();
        c.saveLayer(p.getBounds().inflate(12), Paint()..color = Color.fromRGBO(255, 255, 255, _late(u)));
        _k.blob(c, p, const Color(0xFFFFE45A), const Color(0xFFFF6A2A), gloss: false, line: 0.35);
        c.restore();
      }
    }
    if (!lite && t > 0.2) {
      final u = (t - 0.2) / 0.8;
      _k.fill.color = Color.fromRGBO(70, 70, 82, 0.45 * (1 - u));
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + 0.6;
        c.drawCircle(Offset(math.cos(a), math.sin(a)) * r * (0.3 + 0.4 * u), r * (0.18 + 0.15 * u), _k.fill);
      }
    }
  }

  /// 회전 고리 2겹 + 룬 점 8.
  void _ring(Canvas c, _Hit h, double r, double t) {
    final e = _ease(t);
    for (var k = 0; k < 2; k++) {
      final rr = r * (0.4 + 0.6 * e) * (k == 0 ? 1 : 0.7);
      _stroke
        ..strokeWidth = r * 0.1
        ..color = _a(k == 0 ? h.color : const Color(0xFFFFFFFF), 0.9 * (1 - t));
      c.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rr),
        t * 6 * (k == 0 ? 1 : -1),
        math.pi * 1.6,
        false,
        _stroke,
      );
    }
    _k.fill.color = _a(h.color, 1 - t);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - t * 4;
      c.drawCircle(Offset(math.cos(a), math.sin(a)) * r * (0.5 + 0.5 * e), r * 0.06, _k.fill);
    }
  }

  /// 작은 펑 여러 개: 4~6개가 시간차로 톡톡.
  void _cluster(Canvas c, _Hit h, double r, double t) {
    final n = 4 + h.rarity ~/ 2;
    for (var i = 0; i < n; i++) {
      final delay = i * 0.1;
      final u = (t - delay) / 0.5;
      if (u < 0 || u > 1) continue;
      final a = i * 2.4;
      final at = Offset(math.cos(a), math.sin(a)) * r * 0.55 * ((i % 3) / 2 + 0.3);
      _star(c, at, r * 0.42 * _ease(u) * (1.1 - u * 0.4), 8, const Color(0xFFFFF0A0), h.color, _late(u));
    }
  }

  /// 작은 별 연속: 별 3개가 차례로 반짝 + 탄흔 점.
  void _direct(Canvas c, _Hit h, double r, double t) {
    for (var i = 0; i < 3; i++) {
      final u = (t - i * 0.12) / 0.45;
      if (u < 0 || u > 1) continue;
      final at = Offset((i - 1) * r * 0.35, (i.isOdd ? -1 : 1) * r * 0.12);
      _star(c, at, r * 0.42 * math.sin(u * math.pi), 4, const Color(0xFFFFFFFF), h.color, 1);
    }
    _k.fill.color = _a(const Color(0xFF1A1424), 0.4 * (1 - t));
    c.drawCircle(Offset.zero, r * 0.08, _k.fill);
  }

  /// 창끝 섬광 줄: 길쭉한 다이아 + 양옆으로 뻗는 섬광 줄 2.
  void _pierce(Canvas c, _Hit h, double r, double t) {
    final e = _ease(t);
    final len = r * (0.6 + 1.2 * e);
    final w = r * 0.3 * (1 - t * 0.7);
    final p = Path()
      ..moveTo(-len, 0)
      ..lineTo(0, -w)
      ..lineTo(len, 0)
      ..lineTo(0, w)
      ..close();
    c.saveLayer(p.getBounds().inflate(12), Paint()..color = Color.fromRGBO(255, 255, 255, _late(t)));
    _k.blob(c, p, const Color(0xFFFFFFFF), h.color, gloss: false, line: 0.6);
    c.restore();
    _stroke
      ..strokeWidth = r * 0.04
      ..color = _a(h.color, 1 - t);
    for (final s in const [-1.0, 1.0]) {
      c.drawLine(Offset(-len * 0.5, s * r * 0.3 * e), Offset(len * 0.6, s * r * 0.18 * e), _stroke);
    }
  }

  /// 지지는 열: 붉게 녹은 원판 + 가운데 흰 점 + 위로 오르는 열기 3.
  void _laser(Canvas c, _Hit h, double r, double t) {
    _k.fill.color = _a(Color.lerp(h.color, const Color(0xFFFF5A2A), 0.5)!, 0.6 * (1 - t));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.1, height: r * 0.7), _k.fill);
    _k.fill.color = _a(const Color(0xFFFFFFE0), 1 - t);
    c.drawCircle(Offset.zero, r * 0.18 * (1 - t * 0.5), _k.fill);
    _stroke
      ..strokeWidth = r * 0.07
      ..color = _a(const Color(0xFFFFB45A), 0.8 * (1 - t));
    for (var i = -1; i <= 1; i++) {
      final p = Path()..moveTo(i * r * 0.25, 0);
      for (var j = 1; j <= 4; j++) {
        p.lineTo(i * r * 0.25 + math.sin(j * 1.8 + t * 10) * r * 0.06, -j * r * 0.15 * (0.5 + t));
      }
      c.drawPath(p, _stroke);
    }
  }

  /// 물수제비: 잔물결 3겹이 차례로 + 물방울 튐.
  void _skip(Canvas c, _Hit h, double r, double t) {
    for (var k = 0; k < 3; k++) {
      final u = (t - k * 0.15) / 0.7;
      if (u < 0 || u > 1) continue;
      _stroke
        ..strokeWidth = r * 0.06 * (1 - u)
        ..color = _a(const Color(0xFFE8F8FF), 1 - u);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * (0.4 + 1.4 * u), height: r * (0.2 + 0.7 * u)),
        _stroke,
      );
    }
    _k.fill.color = _a(const Color(0xFFBFE8FF), 1 - t);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi * (0.15 + 0.7 * i / 4);
      c.drawCircle(
        Offset(math.cos(a), math.sin(a)) * r * 0.7 * _ease(t) + Offset(0, r * 0.6 * t * t),
        r * 0.06,
        _k.fill,
      );
    }
  }

  /// 물기둥 + 거품.
  void _water(Canvas c, _Hit h, double r, double t, {required bool lite}) {
    final up = t < 0.4 ? _ease(t / 0.4) : 1 - (t - 0.4) / 0.6;
    final col = Path()
      ..moveTo(-r * 0.22, 0)
      ..quadraticBezierTo(-r * 0.3, -r * 0.9 * up, 0, -r * 1.1 * up)
      ..quadraticBezierTo(r * 0.3, -r * 0.9 * up, r * 0.22, 0)
      ..close();
    c.saveLayer(col.getBounds().inflate(12), Paint()..color = Color.fromRGBO(255, 255, 255, 0.9 * (1 - t * 0.5)));
    _k.blob(c, col, const Color(0xFFF0FCFF), const Color(0xFF6AC8F0), line: 0.6);
    c.restore();
    if (lite) return;
    _stroke
      ..strokeWidth = r * 0.04
      ..color = _a(const Color(0xFFE8F8FF), 1 - t);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + 0.3;
      c.drawCircle(Offset(math.cos(a) * r * 0.7 * _ease(t), -r * 0.3 * t + math.sin(a) * r * 0.25), r * 0.07, _stroke);
    }
  }

  /// 지그재그 갈래 번개 4 + 전기 원.
  void _air(Canvas c, _Hit h, double r, double t) {
    final flick = (t * 12).floor().isEven ? 1.0 : 0.6;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + 0.4;
      final d = Offset(math.cos(a), math.sin(a));
      final n = Offset(-d.dy, d.dx);
      final p = Path()..moveTo(0, 0);
      for (var j = 1; j <= 4; j++) {
        final q = d * (r * 0.25 * j) + n * ((j.isEven ? 1 : -1) * r * 0.1);
        p.lineTo(q.dx, q.dy);
      }
      _stroke
        ..strokeWidth = r * 0.12 * (1 - t)
        ..color = _a(const Color(0xFF1A1424), flick * (1 - t));
      c.drawPath(p, _stroke);
      _stroke
        ..strokeWidth = r * 0.06 * (1 - t)
        ..color = _a(Color.lerp(h.color, const Color(0xFFFFF6A0), 0.5)!, flick * (1 - t));
      c.drawPath(p, _stroke);
    }
    _k.fill.color = _a(const Color(0xFFE8FBFF), 0.8 * (1 - t));
    c.drawCircle(Offset.zero, r * 0.2 * (1 - t), _k.fill);
  }

  /// 베기 X: 두 줄 초승달 칼자국이 차례로 + 반짝.
  void _assault(Canvas c, _Hit h, double r, double t) {
    for (var k = 0; k < 2; k++) {
      final u = (t - k * 0.12) / 0.6;
      if (u < 0 || u > 1) continue;
      c
        ..save()
        ..rotate(k == 0 ? math.pi / 4 : -math.pi / 4);
      final w = r * 0.26 * (1 - u * 0.6);
      final p = Path()
        ..moveTo(-r * 0.9, 0)
        ..quadraticBezierTo(0, -w * 2, r * 0.9, 0)
        ..quadraticBezierTo(0, -w * 0.4, -r * 0.9, 0)
        ..close();
      c.saveLayer(p.getBounds().inflate(12), Paint()..color = Color.fromRGBO(255, 255, 255, _late(u)));
      _k.blob(c, p, const Color(0xFFFFFFFF), h.color, gloss: false, line: 0.5);
      c
        ..restore()
        ..restore();
    }
    if (t < 0.4) _star(c, Offset.zero, r * 0.25 * math.sin(t / 0.4 * math.pi), 4, const Color(0xFFFFFFFF), h.color, 1);
  }

  /// 두꺼운 충격파 + 땅 금 6갈래.
  void _shock(Canvas c, _Hit h, double r, double t) {
    final e = _ease(t);
    _stroke
      ..strokeWidth = r * 0.3 * (1 - t)
      ..color = _a(Color.lerp(h.color, const Color(0xFFFFFFFF), 0.3)!, 0.7 * (1 - t));
    c.drawCircle(Offset.zero, r * (0.2 + 0.9 * e), _stroke);
    _stroke
      ..strokeWidth = r * 0.08
      ..color = _a(const Color(0xFF1A1424), 0.6 * (1 - t));
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + 0.2;
      final p = Path()..moveTo(0, 0);
      for (var j = 1; j <= 3; j++) {
        final aa = a + (j.isEven ? 0.2 : -0.2);
        p.lineTo(math.cos(aa) * r * 0.25 * j * e, math.sin(aa) * r * 0.25 * j * e);
      }
      c.drawPath(p, _stroke);
    }
  }

  /// 외곽선 별([points]갈래).
  void _star(Canvas c, Offset at, double s, int points, Color light, Color dark, double alpha) {
    if (s <= 0.3) return;
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = -math.pi / 2 + i * math.pi / points;
      final rr = i.isEven ? s : s * 0.42;
      final q = at + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    p.close();
    c.saveLayer(p.getBounds().inflate(12), Paint()..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)));
    _k.blob(c, p, light, dark, gloss: false, line: 0.5);
    c.restore();
  }
}
