part of 'top_ultimate.dart';

/// 계열 11종 모양(top_ultimate.dart 300줄 한도로 나눔). t = 0~1(1.1초), s = 배 자리.
extension _UltimateShapes on TopUltimate {
  /// 관통: 왼쪽 아래 → 오른쪽 위로 화면을 가로지르는 거대 창 광선(두께가 부풀었다 가늘어짐) + 창끝.
  void _pierce(Canvas c, Offset s, double t) {
    final a = s + const Offset(-TopUltimate.half - 20, 40);
    final b = s + const Offset(TopUltimate.half + 20, -TopUltimate.reach);
    final head = Offset.lerp(a, b, math.min(1, t / 0.25))!;
    final w = 26 * math.sin(math.min(1, t / 0.8) * math.pi) + 2;
    final e = TopUltimate._env(t);
    _line
      ..strokeWidth = w * 1.8 * _k
      ..color = Color.fromRGBO(255, 210, 90, 0.45 * e);
    c.drawLine(a, head, _line);
    _line
      ..strokeWidth = w * _k
      ..color = Color.fromRGBO(255, 255, 235, 0.95 * e);
    c.drawLine(a, head, _line);
    final dir = (b - a) / (b - a).distance;
    final n = Offset(-dir.dy, dir.dx);
    _path
      ..reset()
      ..moveTo(head.dx + dir.dx * 40, head.dy + dir.dy * 40)
      ..lineTo(head.dx + n.dx * 16, head.dy + n.dy * 16)
      ..lineTo(head.dx - n.dx * 16, head.dy - n.dy * 16)
      ..close();
    _fill.color = Color.fromRGBO(255, 236, 160, e);
    c.drawPath(_path, _fill);
    if (t > 0.25 && t < 0.75) _boom(c, b, 34, (t - 0.25) / 0.5, const Color(0xFFFFC23A)); // 끝 큰 착탄
  }

  /// 레이저: 배에서 빔 3줄이 부채꼴로 180° 휩쓴다.
  void _laser(Canvas c, Offset s, double t, {required bool lite}) {
    final e = TopUltimate._env(t);
    for (var i = 0; i < (lite ? 3 : 5); i++) {
      final a = -math.pi + (t * 1.2 + i / 5) % 1 * math.pi;
      final end = s + Offset(math.cos(a), math.sin(a)) * TopUltimate.reach;
      _line
        ..strokeWidth = 23.8 * _k
        ..color = Color.fromRGBO(255, 90, 160, 0.4 * e);
      c.drawLine(s, end, _line);
      _line
        ..strokeWidth = 8.5 * _k
        ..color = Color.fromRGBO(255, 230, 245, 0.95 * e);
      c.drawLine(s, end, _line);
    }
  }

  /// 수중: 배 위쪽에 거대 소용돌이(나선 팔 4개가 돈다) + 둘레 물기둥.
  void _vortex(Canvas c, Offset s, double t, {required bool lite}) {
    final o = s + const Offset(0, -150);
    final e = TopUltimate._env(t);
    final arms = lite ? 3 : 5;
    for (var k = 0; k < arms; k++) {
      _path.reset();
      for (var i = 0; i <= 24; i++) {
        final u = i / 24;
        final a = k * 2 * math.pi / arms + u * 4 + t * 9;
        final p = o + Offset(math.cos(a), math.sin(a) * 0.7) * (10 + 130 * u * TopUltimate._ease(math.min(1, t * 2)));
        i == 0 ? _path.moveTo(p.dx, p.dy) : _path.lineTo(p.dx, p.dy);
      }
      _line
        ..strokeWidth = 10.2 * _k
        ..color = Color.fromRGBO(120, 220, 255, 0.75 * e);
      c.drawPath(_path, _line);
    }
    for (var k = 0; k < (lite ? 3 : 6); k++) {
      final a = k * math.pi / 3;
      final p = o + Offset(math.cos(a) * 140, math.sin(a) * 90);
      final h = 60 * math.sin(math.min(1, t * 1.6) * math.pi);
      _fill.color = Color.fromRGBO(200, 245, 255, 0.6 * e);
      c.drawRRect(RRect.fromLTRBR(p.dx - 7, p.dy - h, p.dx + 7, p.dy, const Radius.circular(7)), _fill);
    }
  }

  /// 번개: 위쪽 지그재그 자리 7곳에 낙뢰가 차례로 내리꽂힌다.
  void _thunder(Canvas c, Offset s, double t, {required bool lite}) {
    for (var i = 0; i < (lite ? 6 : 12); i++) {
      final at = i * 0.05;
      final u = (t - at) / 0.3;
      if (u < 0 || u >= 1) continue;
      final to = s + Offset(((i * 53) % 9 - 4) * 32.0, -60.0 - (i % 5) * 50);
      final from = to + const Offset(0, -140);
      _path
        ..reset()
        ..moveTo(from.dx, from.dy);
      for (var k = 1; k <= 6; k++) {
        final p = Offset.lerp(from, to, k / 6)!;
        _path.lineTo(p.dx + (k == 6 ? 0 : ((i * 7 + k * 5) % 11 - 5) * 3.0), p.dy);
      }
      _line
        ..strokeWidth = (15.3 * (1 - u) + 2) * _k
        ..color = Color.fromRGBO(255, 230, 90, 1 - u);
      c.drawPath(_path, _line);
      _line
        ..strokeWidth = 5.1 * _k
        ..color = Color.fromRGBO(255, 255, 255, 1 - u);
      c.drawPath(_path, _line);
      _fill.color = Color.fromRGBO(255, 240, 160, 0.7 * (1 - u));
      c.drawCircle(to, 14 + 20 * u, _fill);
    }
  }

  /// 폭발(투척): 융단 폭격 — 배 앞에서 위로 3줄 × 5발이 줄지어 터지며 올라간다.
  void _carpet(Canvas c, Offset s, double t, {required bool lite}) {
    for (var row = 0; row < 5; row++) {
      for (var i = 0; i < (lite ? 3 : 5); i++) {
        final at = row * 0.11 + i * 0.03;
        final u = (t - at) / 0.35;
        if (u < 0 || u >= 1) continue;
        final p = s + Offset((i - 2) * 50.0 + (row.isOdd ? 25 : 0), -60.0 - row * 55);
        _boom(c, p, 22 + 12 * u, u, const Color(0xFFFF8A2A));
      }
    }
  }

  /// 집속: 폭탄 비 — 작은 폭탄이 위에서 떨어져 바둑판 자리에서 연달아 터진다.
  void _bombRain(Canvas c, Offset s, double t, {required bool lite}) {
    for (var i = 0; i < (lite ? 12 : 24); i++) {
      final at = (i * 37 % 16) / 16 * 0.5;
      final p = s + Offset(((i % 4) - 1.5) * 70, -60.0 - (i ~/ 4) * 60);
      final fall = (t - at) / 0.15;
      if (fall >= 0 && fall < 1) {
        _fill.color = const Color(0xFF3A3040);
        c.drawCircle(p + Offset(0, -80 * (1 - fall)), 7, _fill);
      }
      final u = (t - at - 0.15) / 0.3;
      if (u >= 0 && u < 1) _boom(c, p, 12 + 10 * u, u, const Color(0xFFFFC23A));
    }
  }

  /// 돌격: 칼바람 회오리 — 배 둘레 초승달 칼날이 돌며 퍼진다.
  void _whirl(Canvas c, Offset s, double t, {required bool lite}) {
    final e = TopUltimate._env(t);
    final n = lite ? 6 : 12;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n + t * 12;
      final r = 40 + 170 * TopUltimate._ease(t);
      _line
        ..strokeWidth = 8.5 * _k
        ..color = Color.fromRGBO(230, 245, 255, 0.85 * e);
      c.drawArc(Rect.fromCircle(center: s, radius: r), a, 0.6, false, _line);
      _line
        ..strokeWidth = 20.4 * _k
        ..color = Color.fromRGBO(150, 200, 255, 0.25 * e);
      c.drawArc(Rect.fromCircle(center: s, radius: r), a, 0.6, false, _line);
    }
  }

  /// 직사: 일제 사격 — 배 양옆 대포 9문에서 위로 곧은 예광탄 줄 + 포구 섬광.
  void _broadside(Canvas c, Offset s, double t, {required bool lite}) {
    for (var i = 0; i < (lite ? 7 : 13); i++) {
      final at = (i % 3) * 0.08;
      final u = (t - at) / 0.5;
      if (u < 0 || u >= 1) continue;
      final x = s.dx + (i - (lite ? 3 : 6)) * 22.0;
      final y0 = s.dy - 20;
      final head = y0 - TopUltimate.reach * TopUltimate._ease(u);
      _line
        ..strokeWidth = 6.8 * _k
        ..color = Color.fromRGBO(255, 230, 150, 0.9 * (1 - u));
      c.drawLine(Offset(x, head + 60), Offset(x, head), _line);
      if (u < 0.2) _boom(c, Offset(x, y0), 10, u / 0.2, const Color(0xFFFFE07A));
    }
  }

  /// 물수제비: 원반 행렬이 왼쪽에서 오른쪽으로 통통 튀며 지나간다(튈 때마다 물보라 고리).
  void _skipRow(Canvas c, Offset s, double t, {required bool lite}) {
    for (var r = 0; r < (lite ? 2 : 4); r++) {
      final y = s.dy - 70.0 - r * 65;
      final u = (t - r * 0.1).clamp(0.0, 1.0);
      final x = s.dx - TopUltimate.half + 2 * TopUltimate.half * u;
      final hop = math.sin(u * math.pi * 5).abs() * 24;
      _fill.color = Color.fromRGBO(120, 220, 230, TopUltimate._env(t));
      for (var d = 0; d < 3; d++) {
        c.drawOval(Rect.fromCenter(center: Offset(x - d * 34, y - hop + d * 6), width: 40, height: 22), _fill);
      }
      for (var k = 0; k < 5; k++) {
        final kx = s.dx - TopUltimate.half + 2 * TopUltimate.half * k / 5;
        final age = u - k / 5;
        if (age < 0 || age > 0.3) continue;
        _line
          ..strokeWidth = 3.4 * _k
          ..color = Color.fromRGBO(220, 250, 255, 1 - age / 0.3);
        c.drawOval(Rect.fromCenter(center: Offset(kx, y), width: 20 + 80 * age, height: 8 + 30 * age), _line);
      }
    }
  }

  /// 공중: 급강하 폭격 — 위에서 V자 날개 6쌍이 내리꽂혀 깃털 터짐.
  void _dive(Canvas c, Offset s, double t, {required bool lite}) {
    for (var i = 0; i < (lite ? 5 : 10); i++) {
      final at = i * 0.05;
      final u = (t - at) / 0.4;
      if (u < 0 || u >= 1.3) continue;
      final to = s + Offset((i - 4.5) * 30, -80.0 - (i % 3) * 70);
      if (u < 1) {
        final p = to + Offset(-60 * (1 - u), -200 * (1 - u));
        _line
          ..strokeWidth = 6.8 * _k
          ..color = const Color(0xFFFFFFFF);
        c
          ..drawLine(p, p + const Offset(-26, -15), _line)
          ..drawLine(p, p + const Offset(18, -26), _line);
        _line
          ..strokeWidth = 3.4 * _k
          ..color = const Color(0x99FFFFFF);
        c.drawLine(p, p + const Offset(-24, -80), _line);
      } else {
        _boom(c, to, 18, (u - 1) / 0.3, const Color(0xFFBFE8FF));
      }
    }
  }

  /// 고리: 배에서 겹 충격파 3개가 화면 끝까지 퍼진다.
  void _rings(Canvas c, Offset s, double t) {
    for (var i = 0; i < 3; i++) {
      final u = (t - i * 0.15) / 0.75;
      if (u < 0 || u >= 1) continue;
      _line
        ..strokeWidth = (17 * (1 - u) + 2) * _k
        ..color = Color.fromRGBO(140, 200, 255, 0.85 * (1 - u));
      c.drawCircle(s, 30 + 260 * TopUltimate._ease(u), _line);
      _line
        ..strokeWidth = 3.4 * _k
        ..color = Color.fromRGBO(255, 255, 255, 0.8 * (1 - u));
      c.drawCircle(s, 22 + 250 * TopUltimate._ease(u), _line);
    }
  }

  /// 폭발 한 발: 굵은 테 + 불덩이(u 0~1).
  void _boom(Canvas c, Offset p, double r0, double u, Color color) {
    final r = r0 * 1.7;
    _fill.color = color.withValues(alpha: 0.85 * (1 - u));
    c.drawCircle(p, r * (0.6 + 0.4 * u), _fill);
    _fill.color = Color.fromRGBO(255, 250, 220, 0.9 * (1 - u));
    c.drawCircle(p, r * 0.4 * (1 - u * 0.5), _fill);
    _line
      ..strokeWidth = (5.1 * (1 - u) + 0.5) * _k
      ..color = const Color(0xFF1A1424).withValues(alpha: 0.6 * (1 - u));
    c.drawCircle(p, r * (0.7 + 0.5 * u), _line);
  }
}
