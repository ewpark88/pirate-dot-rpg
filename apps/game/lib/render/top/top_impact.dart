import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;

/// 탑다운 범위 공격 임팩트 v2 (사용자 '모레이 같은 범위 스킬 임팩트가 허접하다', S1):
/// 흰 번쩍 코어 → 등급 색 충격파 고리 2겹(빠르게 퍼짐) → 파편(수중은 거품) 입자 → 바닥 잔흔(0.6초에 사라짐).
/// 수중(underwater)은 가운데 물기둥이 솟았다 무너진다. 크기 = 엔진이 이번 틱에 맞힌 적까지의 거리(반경 그대로).
class TopImpact {
  final List<_Hit> _hits = [];
  final _fill = Paint();
  final _ring = Paint()..style = PaintingStyle.stroke;
  static const _lifeMs = 600.0;
  static const _max = 12; // 입자 예산(S1 성능 — '모두 신화' 범위 공격이 매 틱 겹칠 때)

  /// ([x],[y])에 반지름 [radius] 임팩트. [color] = 등급 색, [water] = 수중(물기둥·거품).
  void add(double x, double y, double radius, int color, double atMs, {bool water = false, bool rainbow = false}) {
    if (_hits.length >= _max) _hits.removeAt(0);
    _hits.add(_Hit(x, y, radius, color, atMs, water: water, rainbow: rainbow));
  }

  double _chainNow = -1;
  int _chainN = 0;

  /// 연쇄 폭발(피드백 #4 핵앤슬래시): 같은 프레임 처치가 3마리째부터 그 자리에 작은 폭발이 45ms씩 늦게 이어 터진다(프레임당 6개).
  void chainKill(double x, double y, double now) {
    if (now != _chainNow) {
      _chainNow = now;
      _chainN = 0;
    }
    _chainN++;
    if (_chainN < 3 || _chainN > 8) return;
    add(x, y, 10 + (_chainN % 3) * 3.0, 0xFFFF8A2A, now + (_chainN - 2) * 45);
  }

  void clear() {
    _hits.clear();
    _chainN = 0;
  }

  static double _ease(double t) => 1 - (1 - t) * (1 - t) * (1 - t);

  /// 전장 좌표. [flash] 꺼짐이면 흰 번쩍 코어를 뺀다, [lite](절전·폭발 많음)면 입자를 반.
  void paint(Canvas c, double now, {required bool flash, required bool lite}) {
    _hits.removeWhere((h) => now - h.ms >= _lifeMs);
    for (final h in _hits) {
      final age = now - h.ms;
      if (age < 0) continue;
      final t = age / _lifeMs;
      final at = Offset(h.x, h.y);
      final col = Color(h.color);
      final r = h.radius;
      // 바닥 잔흔: 어두운 물 고리(수중은 거품 고리), 천천히 사라짐
      _ring
        ..strokeWidth = 2.5
        ..color = (h.water ? const Color(0xFFE6F6FF) : const Color(0xFF14243A)).withValues(alpha: 0.35 * (1 - t));
      c.drawCircle(at, r * 0.85, _ring);
      // 타격감 v3 밝기 대비: 첫 2프레임 꽉 찬 흰 원 → 주황 불덩이 → 검은 연기(수중은 연기 대신 물기둥).
      if (t < 0.06) {
        _fill.color = const Color(0xFFFFD24A); // 흰 0% — 노랑 코어(사용자 '흰 번쩍임 눈 아프다')
        c.drawCircle(at, r * 0.6, _fill);
      } else if (t < 0.32) {
        final k = (t - 0.06) / 0.26;
        _fill.color = Color.lerp(const Color(0xFFFFE08A), const Color(0xFFFF5A1A), k)!.withValues(alpha: 1 - k * 0.5);
        c.drawCircle(at, r * (0.55 - 0.2 * k), _fill);
      }
      if (!h.water && t > 0.2) {
        final k = (t - 0.2) / 0.8;
        for (var p = 0; p < 3; p++) {
          final a = p * 2.1 + h.x * 0.05;
          _fill.color = const Color(0xFF231C26).withValues(alpha: 0.55 * (1 - k));
          c.drawCircle(
            at + Offset(math.cos(a) * r * 0.25, math.sin(a) * r * 0.2 - r * 0.3 * k),
            r * (0.18 + 0.15 * k),
            _fill,
          );
        }
      }
      // 등급 색 충격파 고리 2겹
      for (final (delay, width) in const [(0.0, 5.5), (0.12, 3.0)]) {
        final k = ((t - delay) / 0.55).clamp(0.0, 1.0);
        if (k <= 0 || k >= 1) continue;
        _ring
          ..strokeWidth = width * (1 - k) + 0.5
          ..color =
              (h.rainbow
                      ? HSVColor.fromAHSV(1, (k * 360 + delay * 900) % 360, 0.7, 1).toColor()
                      : Color.lerp(const Color(0xFFFFE27A), col, k)!)
                  .withValues(alpha: 1 - k);
        c.drawCircle(at, r * (0.25 + 0.9 * _ease(k)), _ring);
      }
      // 물기둥(수중): 솟았다 무너짐
      if (h.water && t < 0.7) {
        final k = t / 0.7;
        final up = math.sin(math.pi * k);
        final hgt = r * 0.9 * up;
        _fill.color = const Color(0xFFBFE9FF).withValues(alpha: 0.85 * (1 - k * 0.6));
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(h.x - r * 0.18, h.y - hgt, r * 0.36, hgt + 2),
            Radius.circular(r * 0.18),
          ),
          _fill,
        );
        _fill.color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * (1 - k));
        c.drawOval(Rect.fromCenter(center: Offset(h.x, h.y - hgt), width: r * 0.5, height: r * 0.25), _fill);
      }
      // 파편·거품 입자
      final n = lite || _hits.length > 6 ? 4 : 8;
      for (var i = 0; i < n; i++) {
        final a = i * 2 * math.pi / n + h.x * 0.37;
        final d = r * (0.2 + 1.0 * _ease(t)) * (0.7 + 0.3 * ((i * 7) % 5) / 4);
        final lift = h.water ? 0.0 : r * 0.5 * 4 * t * (1 - t);
        _fill.color = (h.water ? const Color(0xFFE6F6FF) : (i.isEven ? col : const Color(0xFF3A3040))).withValues(
          alpha: 1 - t,
        );
        final s = h.water ? 1.5 + (i % 3) : 1.5;
        if (h.water) {
          c.drawCircle(at + Offset(math.cos(a) * d, math.sin(a) * d - lift), s, _fill);
        } else {
          c.drawRect(Rect.fromLTWH(h.x + math.cos(a) * d, h.y + math.sin(a) * d - lift, s * 1.3, s), _fill);
        }
      }
    }
  }
}

class _Hit {
  _Hit(this.x, this.y, this.radius, this.color, this.ms, {required this.water, this.rainbow = false});
  final double x;
  final double y;
  final double radius;
  final int color;
  final double ms;
  final bool water;
  final bool rainbow;
}
