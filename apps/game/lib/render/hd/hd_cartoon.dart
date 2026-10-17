import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, LinearGradient, RadialGradient;

part 'hd_cartoon_boss.dart';

/// HD 카툰 시범(디자인 개편 ④ — 쿵푸할매 서바이버 스타일, 사용자 승인 전 시범만): 2등신·굵은 검정 외곽선·광택 하이라이트·
/// 채도 높은 색. 코드 벡터(AI 아님, OWN). 정면 3/4 시점이라 돌리지 않고 좌우만 뒤집어 쓰는 것을 가정한다.
/// paint는 가운데 원점, 반지름 r(몸 크기 기준) 안에 그린다. t는 애니메이션 시각(ms) — 숨쉬기·꿈틀.
class HdCartoon {
  static const kinds = ['crab', 'jelly', 'piranha', 'kraken'];

  final _fill = Paint()..isAntiAlias = true;
  final _ink = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF1A1424);

  void paint(Canvas c, String kind, double r, double t) {
    _ink.strokeWidth = math.max(2.5, r * 0.11);
    switch (kind) {
      case 'crab':
        _crab(c, r, t);
      case 'jelly':
        _jelly(c, r, t);
      case 'piranha':
        _piranha(c, r, t);
      default:
        _kraken(c, r, t);
    }
  }

  // ---------- 공통 ----------
  /// 몸 덩어리: 위 밝음 → 아래 어두움 그라데이션 + 굵은 외곽선 + 왼쪽 위 광택.
  void _blob(Canvas c, Path p, Color light, Color dark, {bool gloss = true}) {
    final b = p.getBounds();
    // 셰이더 출력은 붓 색 알파를 곱한다 — 앞에서 남은 반투명 색을 지운다.
    _fill
      ..color = const Color(0xFFFFFFFF)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, dark],
      ).createShader(b);
    c.drawPath(p, _fill);
    _fill.shader = null;
    c.drawPath(p, _ink);
    if (gloss) {
      _fill.color = const Color(0x99FFFFFF);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(b.left + b.width * 0.32, b.top + b.height * 0.24),
          width: b.width * 0.28,
          height: b.height * 0.14,
        ),
        _fill,
      );
      _fill.color = const Color(0xCCFFFFFF);
      c.drawCircle(Offset(b.left + b.width * 0.2, b.top + b.height * 0.3), b.width * 0.035, _fill);
    }
  }

  /// 큰 카툰 눈: 흰자 + 검은 눈동자 + 반짝 두 점 + 외곽선. [angry]면 위에 눈썹.
  void _eye(Canvas c, Offset at, double s, {bool angry = false, double look = 0}) {
    _fill.color = const Color(0xFFFFFFFF);
    c
      ..drawOval(Rect.fromCenter(center: at, width: s, height: s * 1.15), _fill)
      ..drawOval(Rect.fromCenter(center: at, width: s, height: s * 1.15), _ink);
    _fill.color = const Color(0xFF1A1424);
    c.drawOval(
      Rect.fromCenter(center: at + Offset(look * s * 0.15, s * 0.08), width: s * 0.55, height: s * 0.68),
      _fill,
    );
    _fill.color = const Color(0xFFFFFFFF);
    c
      ..drawCircle(at + Offset(-s * 0.08 + look * s * 0.15, -s * 0.08), s * 0.14, _fill)
      ..drawCircle(at + Offset(s * 0.12 + look * s * 0.15, s * 0.2), s * 0.06, _fill);
    if (angry) {
      c.drawLine(at + Offset(-s * 0.55, -s * 0.85), at + Offset(s * 0.45, -s * 0.55), _ink);
    }
  }

  // ---------- 게 ----------
  void _crab(Canvas c, double r, double t) {
    final bob = math.sin(t / 220) * r * 0.04;
    final claw = math.sin(t / 180) * 0.15;
    const red = Color(0xFFFF5A48);
    const redD = Color(0xFFC0281E);
    // 다리
    for (final s in const [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final y = r * (0.25 + i * 0.18);
        final p = Path()
          ..moveTo(s * r * 0.6, y)
          ..quadraticBezierTo(s * r * 1.05, y - r * 0.1, s * r * 1.1, y + r * 0.22);
        _ink.strokeWidth *= 2.2;
        c.drawPath(p, _ink);
        _ink.strokeWidth /= 2.2;
        final leg = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _ink.strokeWidth * 1.1
          ..color = redD;
        c.drawPath(p, leg);
      }
    }
    // 집게(번쩍 든)
    for (final s in const [-1.0, 1.0]) {
      c
        ..save()
        ..translate(s * r * 0.85, -r * 0.55 + bob)
        ..rotate(s * (0.35 + claw));
      final arm = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.28), width: r * 0.3, height: r * 0.5));
      _blob(c, arm, red, redD, gloss: false);
      final pincer = Path()
        ..moveTo(-r * 0.32, 0)
        ..cubicTo(-r * 0.4, -r * 0.5, r * 0.05, -r * 0.62, r * 0.12, -r * 0.3)
        ..lineTo(0, -r * 0.18)
        ..lineTo(r * 0.3, -r * 0.42)
        ..cubicTo(r * 0.42, -r * 0.1, r * 0.25, r * 0.15, 0, r * 0.12)
        ..close();
      _blob(c, pincer, red, redD);
      c.restore();
    }
    // 몸통
    final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.15 + bob), width: r * 1.5, height: r * 1.05));
    _blob(c, body, const Color(0xFFFF8A6A), redD);
    // 눈자루 + 눈
    for (final s in const [-1.0, 1.0]) {
      c.drawLine(Offset(s * r * 0.25, -r * 0.2 + bob), Offset(s * r * 0.3, -r * 0.48 + bob), _ink);
      _eye(c, Offset(s * r * 0.3, -r * 0.55 + bob), r * 0.34);
    }
    // 입·볼
    final mouth = Path()
      ..moveTo(-r * 0.15, r * 0.25 + bob)
      ..quadraticBezierTo(0, r * 0.38 + bob, r * 0.15, r * 0.25 + bob);
    c.drawPath(mouth, _ink);
    _fill.color = const Color(0x88FFB0C0);
    for (final s in const [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(s * r * 0.45, r * 0.2 + bob), width: r * 0.22, height: r * 0.12),
        _fill,
      );
    }
  }

  // ---------- 해파리 ----------
  void _jelly(Canvas c, double r, double t) {
    final pulse = 1 + math.sin(t / 260) * 0.05;
    // 촉수(꿈틀)
    for (var i = 0; i < 5; i++) {
      final x = (i - 2) * r * 0.3;
      final p = Path()..moveTo(x, r * 0.2);
      for (var k = 1; k <= 4; k++) {
        p.lineTo(x + math.sin(t / 200 + i + k) * r * 0.12, r * 0.2 + k * r * 0.22);
      }
      _ink.strokeWidth *= 2;
      c.drawPath(p, _ink);
      _ink.strokeWidth /= 2;
      c.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _ink.strokeWidth * 1.1
          ..color = const Color(0xFFD86CF0),
      );
    }
    // 반투명 돔
    final dome = Path()
      ..moveTo(-r * 0.95 * pulse, r * 0.25)
      ..cubicTo(-r * 1.0 * pulse, -r * 1.15, r * 1.0 * pulse, -r * 1.15, r * 0.95 * pulse, r * 0.25)
      ..quadraticBezierTo(r * 0.5, r * 0.4, 0, r * 0.28)
      ..quadraticBezierTo(-r * 0.5, r * 0.4, -r * 0.95 * pulse, r * 0.25)
      ..close();
    _fill
      ..color =
          const Color(0xFFFFFFFF) // 셰이더 출력에 앞의 반투명 색 알파가 곱해지지 않게
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.5),
        colors: [Color(0xF0FFD6FA), Color(0xE0F08AE8), Color(0xD0B04ADC)],
      ).createShader(dome.getBounds());
    c.drawPath(dome, _fill);
    _fill.shader = null;
    c.drawPath(dome, _ink);
    _fill.color = const Color(0xAAFFFFFF);
    c.drawOval(Rect.fromCenter(center: Offset(-r * 0.4, -r * 0.55), width: r * 0.42, height: r * 0.22), _fill);
    // 얼굴
    for (final s in const [-1.0, 1.0]) {
      _eye(c, Offset(s * r * 0.32, -r * 0.2), r * 0.3);
    }
    final smile = Path()
      ..moveTo(-r * 0.12, r * 0.02)
      ..quadraticBezierTo(0, r * 0.14, r * 0.12, r * 0.02);
    c.drawPath(smile, _ink);
  }

  // ---------- 피라냐 ----------
  void _piranha(Canvas c, double r, double t) {
    final sw = math.sin(t / 150) * 0.12;
    // 꼬리
    c
      ..save()
      ..translate(r * 0.85, 0)
      ..rotate(sw);
    final tail = Path()
      ..moveTo(0, 0)
      ..lineTo(r * 0.55, -r * 0.45)
      ..quadraticBezierTo(r * 0.4, 0, r * 0.55, r * 0.45)
      ..close();
    _blob(c, tail, const Color(0xFFFF8A3A), const Color(0xFFC8501A), gloss: false);
    c.restore();
    // 지느러미
    final fin = Path()
      ..moveTo(-r * 0.2, -r * 0.7)
      ..quadraticBezierTo(r * 0.15, -r * 1.15, r * 0.45, -r * 0.6)
      ..close();
    _blob(c, fin, const Color(0xFFFF8A3A), const Color(0xFFC8501A), gloss: false);
    // 몸
    final body = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 1.5));
    _blob(c, body, const Color(0xFF7AA0FF), const Color(0xFF3A52C0));
    // 붉은 배
    final belly = Path()
      ..moveTo(-r * 0.9, r * 0.05)
      ..quadraticBezierTo(0, r * 0.95, r * 0.75, r * 0.2)
      ..quadraticBezierTo(0, r * 0.5, -r * 0.9, r * 0.05)
      ..close();
    _fill.color = const Color(0xFFFF5A5A);
    c.drawPath(belly, _fill);
    // 큰 입 + 이빨
    final mouth = Path()
      ..moveTo(-r * 0.85, -r * 0.05)
      ..quadraticBezierTo(-r * 0.35, r * 0.55, r * 0.1, r * 0.05)
      ..close();
    _fill.color = const Color(0xFF6A1424);
    c
      ..drawPath(mouth, _fill)
      ..drawPath(mouth, _ink);
    _fill.color = const Color(0xFFFFFFFF);
    for (var i = 0; i < 4; i++) {
      final x = -r * 0.72 + i * r * 0.2;
      final p = Path()
        ..moveTo(x, -r * 0.02)
        ..lineTo(x + r * 0.08, r * 0.14)
        ..lineTo(x + r * 0.16, -r * 0.02)
        ..close();
      c.drawPath(p, _fill);
    }
    _eye(c, Offset(-r * 0.2, -r * 0.35), r * 0.42, angry: true, look: -1);
  }
}
