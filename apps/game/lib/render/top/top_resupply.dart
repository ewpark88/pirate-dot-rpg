import 'dart:math' as math;
import 'dart:ui';

/// 빠른 항해 보급(ShipResupplied — 도착 스테이지 권장 레벨까지 무상 강화): 오른 부위마다 낙하산 보급 상자가
/// 하늘에서 배로 떨어지고(0.18초 간격), 닿는 순간 금빛 고리·반짝 + 그 부위가 빛난다([onLand]). 전장 좌표.
class TopResupply {
  double _at = -1000000000;
  final List<String> _parts = [];
  final List<bool> _landed = [];

  /// 상자가 배에 닿을 때(부위 이름) — 부위 빛(Moments.onPartUp).
  void Function(String part)? onLand;

  final _fill = Paint()..isAntiAlias = false;
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  static const _gapMs = 180.0;
  static const _fallMs = 620.0;
  static const _ringMs = 380.0;
  static const _maxCrates = 5;

  /// 보급 시작: 오른 부위 [parts](before < after).
  void start(double now, Iterable<String> parts) {
    _at = now;
    _parts
      ..clear()
      ..addAll(parts.take(_maxCrates));
    _landed
      ..clear()
      ..addAll(List.filled(_parts.length, false));
  }

  void clear() {
    _at = -1000000000;
    _parts.clear();
    _landed.clear();
  }

  void paint(Canvas c, double now, Offset ship) {
    for (var i = 0; i < _parts.length; i++) {
      final age = now - _at - i * _gapMs;
      if (age < 0 || age > _fallMs + _ringMs) continue;
      // 배 둘레 다섯 자리에 나눠 떨어진다
      final side = (i - (_parts.length - 1) / 2) * 12.0;
      final land = ship + Offset(side, -4 + (i.isEven ? 0 : 6));
      if (age < _fallMs) {
        final t = age / _fallMs;
        final e = t * t * (3 - 2 * t);
        final p = Offset(land.dx + math.sin(t * 6 + i) * 4 * (1 - t), land.dy - 150 * (1 - e));
        // 그림자(물 위, 내려올수록 진해짐)
        _fill.color = Color.fromRGBO(10, 30, 60, 0.15 + 0.25 * t);
        c.drawOval(Rect.fromCenter(center: land + const Offset(0, 4), width: 6 + 6 * t, height: 3 + 2 * t), _fill);
        _parachute(c, p, i);
        _crate(c, p);
      } else {
        if (!_landed[i]) {
          _landed[i] = true;
          onLand?.call(_parts[i]);
        }
        final t = (age - _fallMs) / _ringMs;
        _line
          ..strokeWidth = 2.5 * (1 - t) + 0.5
          ..color = Color.fromRGBO(255, 214, 74, 1 - t);
        c.drawCircle(land, 6 + 18 * t, _line);
        _fill.color = Color.fromRGBO(255, 246, 200, 1 - t);
        for (var k = 0; k < 6; k++) {
          final a = k * math.pi / 3 + i;
          final d = 4 + 12 * t;
          c.drawRect(
            Rect.fromCenter(center: land + Offset(math.cos(a) * d, math.sin(a) * d - 6 * t), width: 2, height: 2),
            _fill,
          );
        }
      }
    }
  }

  /// 낙하산: 빨강·흰 줄무늬 반원 + 줄 세 가닥.
  void _parachute(Canvas c, Offset p, int i) {
    final top = p - const Offset(0, 16);
    for (var k = 0; k < 4; k++) {
      _fill.color = k.isEven ? const Color(0xFFE8443A) : const Color(0xFFF6F1E6);
      c.drawArc(
        Rect.fromCenter(center: top, width: 18, height: 12),
        math.pi + k * math.pi / 4,
        math.pi / 4,
        true,
        _fill,
      );
    }
    _line
      ..strokeWidth = 1
      ..color = const Color(0xFF1B1726);
    c
      ..drawArc(Rect.fromCenter(center: top, width: 18, height: 12), math.pi, math.pi, false, _line)
      ..drawLine(top + const Offset(-9, 0), p + const Offset(-3, -3), _line)
      ..drawLine(top, p + const Offset(0, -3), _line)
      ..drawLine(top + const Offset(9, 0), p + const Offset(3, -3), _line);
  }

  /// 보급 상자: 나무 상자 + 진한 테 + 금 띠.
  void _crate(Canvas c, Offset p) {
    final r = Rect.fromCenter(center: p, width: 9, height: 8);
    _fill.color = const Color(0xFF1B1726);
    c.drawRect(r.inflate(1), _fill);
    _fill.color = const Color(0xFFB57B44);
    c.drawRect(r, _fill);
    _fill.color = const Color(0xFF8A5A30);
    c
      ..drawRect(Rect.fromLTWH(r.left, r.top + 3, r.width, 1), _fill)
      ..drawRect(Rect.fromLTWH(r.left + 4, r.top, 1, r.height), _fill);
    _fill.color = const Color(0xFFFFD24A);
    c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1), _fill);
  }
}
