import 'dart:math' as math;
import 'dart:ui';

/// 배 피격·위기 연출 (S1): 배 체력 비율이 프레임 사이에 내려가면 맞음, 오르면 회복으로 본다(이벤트 없이 — 회복 이벤트가 따로 없다).
/// - 맞음: 선체 가장자리에서 나무 파편 5조각(갈색, 포물선) + 작은 회색 연기 한 점. 흰 번쩍은 기존(shipFlashMs).
/// - 체력 50% 아래: 고물 뒤로 흐르는 연기 줄기 하나(25% 아래면 둘), 25% 아래: 선체 위 불꽃 둘. 붉은 화면 가장자리 맥박은 [edge].
/// - 회복: 배 둘레 초록 반짝 0.6초.
/// 배는 늘 또렷 — 연기·불꽃은 갑판 가장자리·뒤쪽에 작게, 반투명. 붐빔·절전(lite)이면 파편 3조각·연기 줄기 하나.
class TopShipDamage {
  final List<(double, double, int)> _hits = []; // 각도, ms, 씨앗
  double _last = -1;
  double _healAt = -1000000000;
  final _fill = Paint()..isAntiAlias = true;
  static const _hitMs = 450.0;
  static const _healMs = 600.0;

  /// 화면 가장자리 붉은 맥박 세기 0~1(체력 25% 아래에서만, 침몰 중 아님).
  static double edge(double hp, double now) => hp > 0 && hp < 0.25 ? 0.5 + 0.5 * math.sin(now / 260) : 0;

  /// 배 중심 [ship](전장 좌표), 선체 반폭 [r], 체력 비율 [hp].
  void paint(Canvas c, Offset ship, double r, double hp, double now, {required bool lite}) {
    if (_last >= 0 && hp < _last - 0.001 && hp > 0) {
      if (_hits.length >= 4) _hits.removeAt(0);
      final seed = (now * 7).toInt();
      _hits.add(((seed % 628) / 100, now, seed));
    } else if (_last >= 0 && hp > _last + 0.005) {
      _healAt = now;
    }
    _last = hp;
    _hits.removeWhere((h) => now - h.$2 > _hitMs);
    for (final (a, at, seed) in _hits) {
      final t = (now - at) / _hitMs;
      final edgeAt = ship + Offset(math.cos(a) * r * 0.9, math.sin(a) * r * 1.4);
      final n = lite ? 3 : 5;
      for (var i = 0; i < n; i++) {
        final aa = a + (i - (n - 1) / 2) * 0.5 + (seed % 7) * 0.05;
        final p = edgeAt + Offset(math.cos(aa), math.sin(aa)) * r * (0.6 + 2.6 * t) + Offset(0, r * 1.6 * t * t);
        c
          ..save()
          ..translate(p.dx, p.dy)
          ..rotate(aa + t * 8);
        _fill.color = Color.fromRGBO(196, 130, 66, 1 - t * t);
        c
          ..drawRect(Rect.fromCenter(center: Offset.zero, width: r * 0.5, height: r * 0.18), _fill)
          ..restore();
      }
      _fill.color = Color.fromRGBO(70, 66, 76, 0.5 * (1 - t));
      c.drawCircle(edgeAt + Offset(0, -r * 0.8 * t), r * (0.3 + 0.45 * t), _fill);
    }
    if (hp > 0 && hp < 0.5) _smoke(c, ship, r, now, hp < 0.25 && !lite ? 2 : 1);
    if (hp > 0 && hp < 0.25) _flames(c, ship, r, now);
    final h = (now - _healAt) / _healMs;
    if (h >= 0 && h < 1) _heal(c, ship, r, h);
  }

  /// 연기 줄기: 고물에서 뒤로 퍼지며 옅어지는 회색 덩이(반투명 — 배를 가리지 않게 뒤쪽·위로).
  void _smoke(Canvas c, Offset ship, double r, double now, int columns) {
    for (var k = 0; k < columns; k++) {
      final base = ship + Offset((k == 0 ? -0.45 : 0.45) * r, r * 1.3); // 고물 — 배가 앞(위)으로 가니 연기는 뒤로 흐름
      for (var i = 0; i < 5; i++) {
        final u = ((now / 900) + i / 5 + k * 0.37) % 1;
        final p = base + Offset((k == 0 ? -1 : 1) * r * 0.5 * u + math.sin(u * 5 + k) * r * 0.2, r * 2.4 * u);
        _fill.color = Color.fromRGBO(56, 52, 62, 0.55 * (1 - u));
        c.drawCircle(p, r * (0.25 + 0.45 * u), _fill);
      }
    }
  }

  /// 불꽃 둘: 선체 양옆에서 흔들리는 주황·노랑 혀.
  void _flames(Canvas c, Offset ship, double r, double now) {
    for (final (sx, sy) in const [(-0.55, 0.25), (0.5, -0.35)]) {
      final at = ship + Offset(sx * r, sy * r);
      final f = 0.8 + 0.2 * math.sin(now / 55 + sx * 9);
      for (final (col, s) in const [(0xFFFF6A2A, 1.0), (0xFFFFD04A, 0.55)]) {
        _fill.color = Color(col).withValues(alpha: 0.9);
        c.drawPath(
          Path()
            ..moveTo(at.dx - r * 0.3 * s, at.dy)
            ..quadraticBezierTo(at.dx, at.dy - r * 1.2 * s * f, at.dx + r * 0.3 * s, at.dy)
            ..close(),
          _fill,
        );
      }
    }
  }

  /// 회복: 초록 반짝 6점이 솟으며 사라짐.
  void _heal(Canvas c, Offset ship, double r, double t) {
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + 0.3;
      final p = ship + Offset(math.cos(a) * r * 1.1, math.sin(a) * r * 1.5 - r * 1.2 * t);
      final s = r * 0.22 * math.sin(math.pi * t);
      _fill.color = Color.fromRGBO(110, 255, 140, 1 - t);
      c
        ..drawRect(Rect.fromCenter(center: p, width: s * 2, height: s * 0.6), _fill)
        ..drawRect(Rect.fromCenter(center: p, width: s * 0.6, height: s * 2), _fill);
    }
  }
}
