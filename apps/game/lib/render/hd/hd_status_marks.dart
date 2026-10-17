import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 특성 표식 HD(S1 — 화상·감속·취약을 착탄처럼 눈에 띄게): 상태 걸린 적 둘레에
/// 화상 = 불꽃 꽃잎 3장이 일렁이며 돎 · 감속 = 얼음 수정 3개가 천천히 돎 + 옅은 서리 고리 · 취약 = 초록 방울이 아래로 똑똑.
/// 모양은 한 번 그린 Picture를 돌려 쓴다(무리 100마리여도 drawPicture만). 전장 좌표.
class HdStatusMarks {
  final _k = HdKit();
  late final Picture _petal = _make((c) {
    final p = Path()
      ..moveTo(0, 5)
      ..quadraticBezierTo(-4.5, 0, 0, -6)
      ..quadraticBezierTo(4.5, 0, 0, 5)
      ..close();
    _k.blob(c, p, const Color(0xFFFFE45A), const Color(0xFFFF5A2A), gloss: false);
  });
  late final Picture _crystal = _make((c) {
    final p = Path()
      ..moveTo(0, -6)
      ..lineTo(3.2, 0)
      ..lineTo(0, 6)
      ..lineTo(-3.2, 0)
      ..close();
    _k.blob(c, p, const Color(0xFFFFFFFF), const Color(0xFF7AC8F4), gloss: false);
  });
  late final Picture _drop = _make((c) {
    final p = Path()
      ..moveTo(0, -5)
      ..quadraticBezierTo(4, 1, 0, 5)
      ..quadraticBezierTo(-4, 1, 0, -5)
      ..close();
    _k.blob(c, p, const Color(0xFFB8FF7A), const Color(0xFF3AA83A), gloss: false);
  });
  final _ring = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  Picture _make(void Function(Canvas c) draw) {
    final rec = PictureRecorder();
    _k.ink.strokeWidth = 1.3;
    draw(Canvas(rec));
    return rec.endRecording();
  }

  /// 적 하나: 자리 [at], 그림 반지름 [r], 시각 [now], 적 [id](위상 어긋나게).
  void paint(
    Canvas c,
    Offset at,
    double r,
    double now,
    int id, {
    required bool burning,
    required bool slowed,
    required bool vulnerable,
  }) {
    final s = (r / 9).clamp(0.7, 2.2);
    if (burning) {
      for (var i = 0; i < 3; i++) {
        final a = now / 380 + id + i * 2 * math.pi / 3;
        final flick = 0.85 + 0.25 * math.sin(now / 70 + i + id);
        _put(
          c,
          at + Offset(math.cos(a) * r * 0.95, math.sin(a) * r * 0.7 - r * 0.15),
          a + math.pi / 2,
          s * flick,
          _petal,
        );
      }
    }
    if (slowed) {
      _ring
        ..strokeWidth = 1.5 * s
        ..color = const Color(0x88CFEFFF);
      c.drawOval(Rect.fromCenter(center: at + Offset(0, r * 0.35), width: r * 2, height: r * 0.8), _ring);
      for (var i = 0; i < 3; i++) {
        final a = now / 900 + id + i * 2 * math.pi / 3;
        _put(c, at + Offset(math.cos(a) * r * 1.05, math.sin(a) * r * 0.45 + r * 0.2), 0, s, _crystal);
      }
    }
    if (vulnerable) {
      for (var i = 0; i < 2; i++) {
        final u = (now / 700 + i * 0.5 + id * 0.13) % 1;
        _put(c, at + Offset((i == 0 ? -1 : 1) * r * 0.45, r * (0.5 + u * 0.7)), 0, s * (1 - u * 0.4), _drop);
      }
    }
  }

  void _put(Canvas c, Offset at, double rot, double s, Picture p) {
    c
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(rot)
      ..scale(s)
      ..drawPicture(p)
      ..restore();
  }
}
