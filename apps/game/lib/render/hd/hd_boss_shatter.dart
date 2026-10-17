import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 보스 처치 HD 터짐(사용자 '핵앤슬래시 쾌감' — 큰 보스가 쓰러질 때 부서지는 조각·연기가 HD 그림과 어울리게):
/// ① 카툰 '펑!' 별 모양 섬광(노랑·흰, 굵은 외곽선) ② 보스 색 덩어리 조각 10개(외곽선·광택, 포물선으로 튀며 돎)
/// ③ 둥근 카툰 연기 8뭉치(옅은 회색·가는 외곽선, 커지며 오르고 사라짐). 전장 좌표, 크기는 보스 반지름 기준.
class HdBossShatter {
  final _k = HdKit();
  final List<_Burst> _bursts = [];
  static const _ms = 1100.0;

  /// 보스 처치: 자리 [at], 반지름 [r](그림 배율 반영), 몸 색 [color].
  void burst(double now, Offset at, double r, int color, {bool lite = false}) {
    if (_bursts.length >= 3) _bursts.removeAt(0);
    _bursts.add(_Burst(now, at, r, Color(color), lite: lite));
  }

  bool get active => _bursts.isNotEmpty;

  void clear() => _bursts.clear();

  void paint(Canvas c, double now) {
    _bursts.removeWhere((b) => now - b.at > _ms || now < b.at);
    for (final b in _bursts) {
      final t = (now - b.at) / _ms;
      _k.ink.strokeWidth = math.max(1.2, b.r * 0.06);
      _smoke(c, b, t);
      _chunks(c, b, t);
      if (t < 0.28) _pow(c, b, t / 0.28);
    }
  }

  /// 카툰 섬광: 뾰족한 별(12갈래)이 커졌다 사라짐 + 안쪽 흰 별.
  void _pow(Canvas c, _Burst b, double u) {
    final grow = 1 - (1 - u) * (1 - u);
    final fade = 1 - u;
    for (final (scale, light, dark) in const [
      (1.0, Color(0xFFFFE45A), Color(0xFFFF9A2A)),
      (0.55, Color(0xFFFFFFFF), Color(0xFFFFF0B0)),
    ]) {
      final rr = b.r * (0.6 + 1.5 * grow) * scale;
      final p = Path();
      for (var i = 0; i < 24; i++) {
        final a = i * math.pi / 12 + b.spin;
        final rad = i.isEven ? rr : rr * 0.62;
        final q = b.pos + Offset(math.cos(a), math.sin(a)) * rad;
        i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
      }
      p.close();
      c.saveLayer(p.getBounds().inflate(4), Paint()..color = Color.fromRGBO(255, 255, 255, fade));
      _k.blob(c, p, light, dark, gloss: false, line: 0.8);
      c.restore();
    }
  }

  /// 몸 조각: 불규칙 다각형이 사방으로 포물선 비행·회전, 끝 무렵 작아지며 사라짐.
  void _chunks(Canvas c, _Burst b, double t) {
    final n = b.lite ? 5 : 10;
    final dark = Color.lerp(b.color, const Color(0xFF1A1424), 0.45)!;
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi + b.spin;
      final speed = b.r * (2.2 + (i % 3) * 0.6);
      final pos = b.pos + Offset(math.cos(a) * speed * t, math.sin(a) * speed * t * 0.75 - b.r * 1.6 * t * (1 - t) * 2);
      final s = b.r * (0.22 + (i % 4) * 0.05) * (1 - math.max(0, t - 0.6) / 0.4);
      if (s <= 0) continue;
      c
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(a + t * (i.isEven ? 7 : -6));
      final p = Path()
        ..moveTo(-s, -s * 0.4)
        ..lineTo(-s * 0.2, -s)
        ..lineTo(s * 0.9, -s * 0.5)
        ..lineTo(s, s * 0.5)
        ..lineTo(-s * 0.3, s * 0.9)
        ..close();
      _k.blob(c, p, b.color, dark, line: 0.7);
      c.restore();
    }
  }

  /// 카툰 연기: 둥근 뭉치가 커지며 위로 오르고 옅어진다.
  void _smoke(Canvas c, _Burst b, double t) {
    if (t < 0.08) return;
    final u = (t - 0.08) / 0.92;
    final n = b.lite ? 4 : 8;
    final w = _k.ink.strokeWidth;
    _k.ink.strokeWidth = w * 0.5;
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi + b.spin * 0.5;
      final d = b.r * (0.5 + 0.9 * u);
      final at = b.pos + Offset(math.cos(a) * d, math.sin(a) * d * 0.6 - b.r * 0.9 * u);
      final rad = b.r * (0.28 + 0.3 * u) * (0.8 + (i % 3) * 0.15);
      final alpha = (1 - u) * 0.85;
      _k.fill.color = Color.fromRGBO(236, 240, 248, alpha);
      c.drawCircle(at, rad, _k.fill);
      _k.ink.color = Color.fromRGBO(70, 76, 96, alpha * 0.7);
      c.drawCircle(at, rad, _k.ink);
    }
    _k.ink
      ..strokeWidth = w
      ..color = HdKit.inkColor;
  }
}

class _Burst {
  _Burst(this.at, this.pos, this.r, this.color, {required this.lite}) : spin = (pos.dx * 7.3 + pos.dy * 3.1) % 1.0;
  final double at;
  final Offset pos;
  final double r;
  final Color color;
  final bool lite;
  final double spin;
}
