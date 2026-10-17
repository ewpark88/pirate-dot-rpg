import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 배 스킨 12종 HD v2 디테일(S1): 스킨마다 고유 장식 하나 더 + 유료(패스·상점) 스킨은 은은한 반짝 입자('산 보람').
/// 배 기준 좌표(뱃머리 위, 칸 크기 size, 원점 = 가운데). 전장·상점·패스 미리보기(now 0이면 멈춘 한 장면) 모두.
///   king 고물 금 등불 한 쌍 · ghostship 뱃머리 초록 유령 등불 · frost 돛 눈송이 문양 · lava 뱃머리 불 등불 ·
///   fairy 돛대 끝 별 깃발 · festival 돛 사탕 소용돌이 문양 · abyss 뱃머리 아귀 초롱 ·
///   pass_s1 돛 보라 방패 문장 · sprout 뱃머리 무당벌레 · golden_galleon 돛 금화 문양 · jolly_flag 돛 엇갈린 칼 ·
///   coral_yacht 고물 불가사리.
class HdSkinExtra {
  static const paid = {'pass_s1', 'sprout', 'golden_galleon', 'jolly_flag', 'coral_yacht'};
  static const _sparkColor = {
    'pass_s1': Color(0xFFD8C8FF),
    'sprout': Color(0xFFDFFFC0),
    'golden_galleon': Color(0xFFFFE680),
    'jolly_flag': Color(0xFFFFD0C8),
    'coral_yacht': Color(0xFFFFD8E8),
  };

  final _k = HdKit();
  final _fill = Paint()..isAntiAlias = true;
  final _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void over(Canvas c, String skin, Size size, double now) {
    final w = size.width;
    final h = size.height;
    _k.ink.strokeWidth = math.max<double>(0.8, w * 0.03);
    final bow = Offset(0, -h * 0.44);
    final sail = Offset(0, -h * 0.02);
    final stern = Offset(0, h * 0.38);
    final swing = math.sin(now / 500) * w * 0.02;
    switch (skin) {
      case 'king':
        for (final s in const [-1.0, 1.0]) {
          _lantern(c, stern + Offset(s * w * 0.2, -h * 0.02), w * 0.07, const Color(0xFFFFE070), now);
        }
      case 'ghostship':
        _lantern(c, bow + Offset(swing, -h * 0.03), w * 0.08, const Color(0xFF7CFFB0), now);
      case 'frost':
        _line
          ..strokeWidth = w * 0.035
          ..color = const Color(0xEEFFFFFF);
        for (var i = 0; i < 3; i++) {
          final d = Offset(math.cos(i * math.pi / 3), math.sin(i * math.pi / 3)) * w * 0.12;
          c.drawLine(sail - d, sail + d, _line);
        }
      case 'lava':
        _lantern(c, bow + Offset(swing, -h * 0.03), w * 0.08, const Color(0xFFFF8A2A), now);
      case 'fairy':
        final top = Offset(0, -h * 0.3);
        _fill.color = const Color(0xFFFF9ACF);
        c.drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..lineTo(top.dx + w * 0.22, top.dy + h * 0.03 + swing * 0.5)
            ..lineTo(top.dx, top.dy + h * 0.07)
            ..close(),
          _fill,
        );
        _star(c, top + Offset(w * 0.09, h * 0.035), w * 0.05, const Color(0xFFFFF4A0));
      case 'festival':
        _line.strokeWidth = w * 0.04;
        for (var i = 0; i < 3; i++) {
          _line.color = i.isEven ? const Color(0xFFFF5A7A) : const Color(0xFFFFFFFF);
          c.drawArc(
            Rect.fromCircle(center: sail, radius: w * (0.05 + i * 0.035)),
            i * 1.2 + now / 400,
            4,
            false,
            _line,
          );
        }
      case 'abyss':
        _line
          ..strokeWidth = w * 0.025
          ..color = const Color(0xFF3A4A6A);
        final lure = bow + Offset(swing, -h * 0.1);
        c.drawLine(bow, lure, _line);
        _glow(c, lure, w * 0.06, const Color(0xFF7CF4FF), now);
      case 'pass_s1':
        final p = Path()
          ..moveTo(sail.dx - w * 0.1, sail.dy - h * 0.05)
          ..lineTo(sail.dx + w * 0.1, sail.dy - h * 0.05)
          ..lineTo(sail.dx + w * 0.1, sail.dy + h * 0.01)
          ..quadraticBezierTo(sail.dx, sail.dy + h * 0.07, sail.dx - w * 0.1, sail.dy + h * 0.01)
          ..close();
        _k.blob(c, p, const Color(0xFF8A6AF0), const Color(0xFF3A2490), gloss: false, line: 0.7);
        _star(c, sail, w * 0.05, const Color(0xFFFFE45A));
      case 'sprout':
        final at = bow + Offset(0, h * 0.06);
        _k.blob(
          c,
          Path()..addOval(Rect.fromCircle(center: at, radius: w * 0.06)),
          const Color(0xFFFF4A3A),
          const Color(0xFFB0201A),
          gloss: false,
          line: 0.6,
        );
        _fill.color = const Color(0xFF1A1424);
        c
          ..drawCircle(at + Offset(0, -w * 0.05), w * 0.03, _fill)
          ..drawCircle(at + Offset(-w * 0.025, w * 0.01), w * 0.012, _fill)
          ..drawCircle(at + Offset(w * 0.025, w * 0.015), w * 0.012, _fill);
      case 'golden_galleon':
        _k.blob(
          c,
          Path()..addOval(Rect.fromCircle(center: sail, radius: w * 0.1)),
          const Color(0xFFFFE070),
          const Color(0xFFD8901A),
          gloss: false,
          line: 0.7,
        );
        _line
          ..strokeWidth = w * 0.025
          ..color = const Color(0xFFB0700A);
        c.drawCircle(sail, w * 0.06, _line);
      case 'jolly_flag':
        _line.strokeWidth = w * 0.035;
        for (final s in const [-1.0, 1.0]) {
          final a = sail + Offset(-s * w * 0.1, -h * 0.05);
          final b = sail + Offset(s * w * 0.1, h * 0.05);
          _line.color = const Color(0xFF1A1424);
          c.drawLine(a, b, _line..strokeWidth = w * 0.05);
          _line.color = const Color(0xFFE8F0FA);
          c.drawLine(a, b, _line..strokeWidth = w * 0.025);
        }
      case 'coral_yacht':
        final p = Path();
        final at = stern + Offset(w * 0.12, -h * 0.03);
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final r = i.isEven ? w * 0.08 : w * 0.035;
          final q = at + Offset(math.cos(a), math.sin(a)) * r;
          i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
        }
        p.close();
        _k.blob(c, p, const Color(0xFFFFA070), const Color(0xFFE0603A), gloss: false, line: 0.6);
    }
    final spark = _sparkColor[skin];
    if (spark != null) _sparkles(c, size, spark, now);
  }

  /// 유료 스킨 반짝: 선체 둘레 6점이 차례로 반짝(멈춘 미리보기는 일부만 켠 한 장면).
  void _sparkles(Canvas c, Size size, Color color, double now) {
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + 0.5;
      final at = Offset(math.cos(a) * size.width * 0.42, math.sin(a) * size.height * 0.4);
      final double tw = math.max(0, math.sin(now / 260 + i * 1.7));
      if (tw <= 0.05 && now != 0) continue;
      _star(
        c,
        at,
        size.width * 0.045 * (now == 0 ? 0.8 : 0.5 + 0.5 * tw),
        color.withValues(alpha: now == 0 ? 0.8 : tw),
      );
    }
  }

  void _lantern(Canvas c, Offset at, double r, Color color, double now) {
    _glow(c, at, r, color, now);
    _line
      ..strokeWidth = r * 0.3
      ..color = const Color(0xFF3A2A1A);
    c.drawLine(at + Offset(0, -r * 1.1), at + Offset(0, -r * 1.6), _line);
  }

  void _glow(Canvas c, Offset at, double r, Color color, double now) {
    final pulse = now == 0 ? 1.0 : 0.8 + 0.2 * math.sin(now / 180);
    _fill.color = color.withValues(alpha: 0.3 * pulse);
    c.drawCircle(at, r * 2.2, _fill);
    _k.blob(c, Path()..addOval(Rect.fromCircle(center: at, radius: r)), const Color(0xFFFFFFF0), color, line: 0.6);
  }

  void _star(Canvas c, Offset at, double s, Color color) {
    _fill.color = color;
    c.drawPath(
      Path()
        ..moveTo(at.dx, at.dy - s)
        ..lineTo(at.dx + s * 0.3, at.dy - s * 0.3)
        ..lineTo(at.dx + s, at.dy)
        ..lineTo(at.dx + s * 0.3, at.dy + s * 0.3)
        ..lineTo(at.dx, at.dy + s)
        ..lineTo(at.dx - s * 0.3, at.dy + s * 0.3)
        ..lineTo(at.dx - s, at.dy)
        ..lineTo(at.dx - s * 0.3, at.dy - s * 0.3)
        ..close(),
      _fill,
    );
  }
}
