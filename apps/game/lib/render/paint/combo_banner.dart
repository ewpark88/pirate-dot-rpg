import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/pixel_font.dart';

/// 콤보 배너 v2 (피드백 #4 '시작 10분 핵앤슬래시 감성'): 큰 'x37' + 아래 작은 'COMBO'.
/// 처치마다 '쿵' 커졌다 돌아오고, 연쇄가 길수록 크고 뜨거운 색(노랑 → 주황 → 빨강 → 무지개),
/// 10·25·50·100·200…을 넘는 순간 고리·불꽃이 터진다(`onMilestone`으로 흔들림·소리). HUD 도트 좌표.
class ComboBanner {
  final _num = PixelText();
  final _word = PixelText();
  final _paint = Paint()..isAntiAlias = false;
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  int _last = 0;
  double _milestoneAt = -1000000000;
  int _milestoneColor = 0xFFFFD23F;

  static const _punchMs = 150.0;
  static const _burstMs = 450.0;
  static const _milestones = [10, 25, 50, 100];
  static const _glyphH = 5;

  /// 연쇄 [count]에 따른 (글자 배율, 색). [now]는 무지개 순환용.
  static (int, int) look(int count, double now, int base) {
    if (count >= 100) {
      final hue = (now / 8) % 360;
      return (6, _hsv(hue, 0.75, 1));
    }
    if (count >= 50) return (5, 0xFFFF4A3A);
    if (count >= 25) return (4, 0xFFFF9A2E);
    if (count >= 10) return (4, base);
    return (3, base);
  }

  static bool _crossed(int from, int to) {
    for (final m in _milestones) {
      if (from < m && to >= m) return true;
    }
    return to >= 200 && from ~/ 100 != to ~/ 100;
  }

  /// 가운데 x [cx], 위 y [y]. [lastAddMs] = 마지막 처치 시각.
  void paint(
    Canvas c,
    double cx,
    double y,
    int count,
    double now,
    double lastAddMs, {
    required int minKills,
    required int baseColor,
    required void Function(int count) onMilestone,
    bool fever = false,
  }) {
    if (count > _last && _crossed(_last, count)) {
      _milestoneAt = now;
      onMilestone(count);
    }
    _last = count;
    if (count < minKills) return;
    final (s0, color) = look(count, (now / 100).floorToDouble() * 100, baseColor);
    final scale = fever ? s0 + 1 : s0; // 피버 v2: 콤보 숫자 대형
    _milestoneColor = color;
    _num.set('x$count', color, scale);
    _word.set('COMBO', color, math.max(2, scale - 2));
    final k = ((now - lastAddMs) / _punchMs).clamp(0.0, 1.0);
    final punch = 1 + 0.45 * (1 - k) * (1 - k);
    final numH = (_glyphH * scale).toDouble();
    final midY = y + numH / 2;
    _burst(c, cx, midY, now, scale);
    c
      ..save()
      ..translate(cx, midY)
      ..scale(punch)
      ..translate(-cx, -midY);
    _num.draw(c, cx - (_num.width / 2).floorToDouble(), y);
    _word.draw(c, cx - (_word.width / 2).floorToDouble(), y + numH + 2);
    c.restore();
  }

  /// 단계 넘김 터짐: 퍼지는 두 겹 고리 + 불꽃 10개.
  void _burst(Canvas c, double cx, double cy, double now, int scale) {
    final t = (now - _milestoneAt) / _burstMs;
    if (t < 0 || t >= 1) return;
    final r = 6.0 * scale + 40 * (1 - (1 - t) * (1 - t));
    _ring
      ..strokeWidth = 3 * (1 - t) + 1
      ..color = Color(_milestoneColor).withValues(alpha: 1 - t);
    c.drawCircle(Offset(cx, cy), r, _ring);
    _ring
      ..strokeWidth = 1
      ..color = Color.fromRGBO(255, 255, 255, 0.8 * (1 - t));
    c.drawCircle(Offset(cx, cy), r * 0.7, _ring);
    _paint.color = Color(_milestoneColor).withValues(alpha: 1 - t);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 + 0.3;
      final d = r * (0.8 + 0.4 * (i % 2));
      c.drawRect(Rect.fromLTWH(cx + math.cos(a) * d * 1.6, cy + math.sin(a) * d * 0.8, 2, 2), _paint);
    }
  }
}

/// HSV → ARGB (무지개 콤보).
int _hsv(double hue, double sat, double val) {
  final h = hue / 60;
  final ch = val * sat;
  final x = ch * (1 - (h % 2 - 1).abs());
  final (r, g, b) = switch (h.floor() % 6) {
    0 => (ch, x, 0.0),
    1 => (x, ch, 0.0),
    2 => (0.0, ch, x),
    3 => (0.0, x, ch),
    4 => (x, 0.0, ch),
    _ => (ch, 0.0, x),
  };
  final m = val - ch;
  int to(double v) => ((v + m) * 255).round().clamp(0, 255);
  return 0xFF000000 | to(r) << 16 | to(g) << 8 | to(b);
}
