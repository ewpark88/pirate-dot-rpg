import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/pixel_font.dart';

/// 타격감·무게감 v3 (사용자 '화려하지만 강렬한 임팩트가 없다', S1): 강도 단계 — 약(보통 명중: 흰 번쩍만) · 중(범위·치명) · 강(보스·궁극기).
/// - 렌더 히트스톱: 강(보스·궁극기)만 50ms 재생을 멈춘다(엔진 무관), 0.6초에 한 번(남발 금지 — 첫 불만 '다 멈춘다').
/// - 방향 흔들림: 맞은 쪽으로 중 2 · 강 4dp 밀렸다 120ms에 복귀(흔들기 설정, 피버 중엔 세로만 — 그리는 쪽이 판단).
/// - 넉백: 맞은 적이 충격 중심 반대로 3~5단위 튕겼다 150ms에 돌아온다(그림만).
/// - 처치: 적이 터지며 잉크·조각이 튄다.
class TopJuice {
  double _freeze = 0;
  double _lastFreezeAt = -1000000000;
  Offset _kick = Offset.zero;
  double _kickAt = -1000000000;
  final Map<int, (Offset, double)> _knock = {}; // 적 id → (튕김 벡터, 시작 ms)
  final List<(double, double, double, int, bool)> _pops = []; // x, y, ms, 크기, 크게(POP!)
  double _popNow = -1;
  int _popN = 0;
  final Map<int, double> _squash = {}; // 적 id → 맞은 ms (찌그러졌다 튐)
  static const _squashMs = 160.0;
  final _fill = Paint();
  static const _kickMs = 120.0;
  static const _knockMs = 150.0;

  /// 이번 프레임 재생을 멈추는가(멈추면 남은 시간을 줄인다).
  bool frozen(double dtMs) {
    if (_freeze <= 0) return false;
    _freeze -= dtMs;
    return true;
  }

  /// 중(범위·치명)·강(보스·궁극기) 명중: 히트스톱 + 방향 흔들림. [dir] = 배 → 맞은 곳 방향(단위 벡터 아니어도 됨).
  void hit(double now, Offset dir, {required bool strong, required bool shake, bool crit = false}) {
    // 멈춤은 강(보스·궁극기) 50ms·치명 40ms, 0.6초에 한 번 — 치명마다 멈추면 '몬스터가 다 멈춘다'(사용자 첫 불만)로 돌아간다.
    if ((strong || crit) && now - _lastFreezeAt >= 600) {
      _freeze = strong ? 50 : 40;
      _lastFreezeAt = now;
    }
    if (!shake) return;
    final len = dir.distance;
    _kick = len < 1e-6 ? Offset.zero : dir / len * (strong ? 4 : 2);
    _kickAt = now;
  }

  /// 지금 화면 밀림(dp).
  Offset kick(double now) {
    final t = (now - _kickAt) / _kickMs;
    if (t < 0 || t >= 1) return Offset.zero;
    return _kick * (1 - t) * (1 - t);
  }

  /// 적 [id]가 [from]에서 맞아 바깥으로 튕김.
  void knock(int id, Offset at, Offset from, double now, {double units = 4}) {
    final d = at - from;
    final len = d.distance;
    if (_knock.length > 80) _knock.removeWhere((_, v) => now - v.$2 > _knockMs);
    _knock[id] = (len < 1e-6 ? const Offset(0, -1) * units : d / len * units, now);
  }

  /// 적 [id]의 지금 튕김 오프셋.
  Offset knockOf(int id, double now) {
    final k = _knock[id];
    if (k == null) return Offset.zero;
    final t = (now - k.$2) / _knockMs;
    if (t < 0 || t >= 1) return Offset.zero;
    return k.$1 * math.sin(math.pi * t);
  }

  /// 손맛 v4: 적 [id]가 맞았다 — 납작하게 찌그러졌다가 길쭉하게 튀고 돌아온다(그리기만).
  void squash(int id, double now) {
    if (_squash.length > 96) _squash.removeWhere((_, t) => now - t > _squashMs);
    _squash[id] = now;
  }

  final List<(double, double, double)> _stars = []; // 치명 반짝 별 x, y, ms
  static const _starMs = 260.0;

  /// 손맛 v4 치명: 그 자리에 큰 네 갈래 반짝 별(돌며 커졌다 사라짐).
  void critStar(double x, double y, double now) {
    if (_stars.length >= 12) _stars.removeAt(0);
    _stars.add((x, y, now));
  }

  void _paintStars(Canvas c, double now) {
    _stars.removeWhere((p) => now - p.$3 > _starMs);
    for (final (x, y, at) in _stars) {
      final t = (now - at) / _starMs;
      final r = 4 + 10 * (t < 0.4 ? t / 0.4 : 1 - (t - 0.4) / 0.6 * 0.5);
      final rot = t * 1.2;
      _star.reset();
      for (var j = 0; j < 8; j++) {
        final rr = j.isEven ? r : r * 0.22;
        final a = rot + j * math.pi / 4;
        final px = x + math.cos(a) * rr;
        final py = y + math.sin(a) * rr;
        j == 0 ? _star.moveTo(px, py) : _star.lineTo(px, py);
      }
      _fill.color = const Color(0xFFFFE24A).withValues(alpha: 1 - t);
      c.drawPath(_star..close(), _fill);
      _fill.color = const Color(0xFFFFFFFF).withValues(alpha: 1 - t);
      c.drawCircle(Offset(x, y), r * 0.18, _fill);
    }
  }

  /// 적 [id]의 지금 (가로, 세로) 배율 — 맞은 지 [_squashMs] 안이면, 아니면 null.
  (double, double)? squashOf(int id, double now) {
    final t0 = _squash[id];
    if (t0 == null) return null;
    final t = (now - t0) / _squashMs;
    if (t < 0 || t >= 1) return null;
    // 0~0.3 납작(가로 1.3·세로 0.7) → 0.3~0.65 길쭉(0.85·1.2) → 1 제자리
    final k = t < 0.3 ? t / 0.3 : (t < 0.65 ? (t - 0.3) / 0.35 : (t - 0.65) / 0.35);
    final (ax, ay, bx, by) = t < 0.3
        ? (1.0, 1.0, 1.3, 0.7)
        : (t < 0.65 ? (1.3, 0.7, 0.85, 1.2) : (0.85, 1.2, 1.0, 1.0));
    return (ax + (bx - ax) * k, ay + (by - ay) * k);
  }

  /// 처치: 그 자리에서 동글동글 파스텔 조각(별·하트·동그라미)과 금빛 점이 통통 튄다([size] = 적 크기 단위).
  /// 같은 프레임 3마리째부터는 'POP!'이 붙는 큰 처치.
  void pop(double x, double y, double now, int size) {
    if (now != _popNow) {
      _popNow = now;
      _popN = 0;
    }
    _popN++;
    if (_pops.length >= 24) _pops.removeAt(0);
    _pops.add((x, y, now, size, _popN >= 3));
  }

  void clear() {
    _freeze = 0;
    _knock.clear();
    _pops.clear();
    _squash.clear();
    _stars.clear();
  }

  /// 카툰 연기 구름(HD 처치 '펑'): 뭉게 4개가 부풀며 잉크 테와 함께 옅어진다.
  void _puff(Canvas c, double x, double y, double size, double k) {
    final grow = 1 - (1 - k) * (1 - k);
    final a = 1 - k;
    for (var j = 0; j < 4; j++) {
      final ang = j * math.pi / 2 + x * 0.07;
      final o = Offset(x + math.cos(ang) * size * 0.55 * grow, y + math.sin(ang) * size * 0.45 * grow - 3 * grow);
      final r = size * (0.45 + 0.55 * grow) * (j.isEven ? 1 : 0.8);
      _fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Color.fromRGBO(26, 20, 36, 0.55 * a);
      c.drawCircle(o, r, _fill);
      _fill
        ..style = PaintingStyle.fill
        ..color = Color.fromRGBO(255, 255, 255, 0.85 * a);
      c.drawCircle(o, r, _fill);
    }
  }

  static const _popMs = 560.0;
  static const _pastel = [0xFFFF6FB5, 0xFF5FD8FF, 0xFFFFD23A, 0xFF7CF06A, 0xFFB98CFF, 0xFFFF9A3C];
  final _star = Path();
  final _shape = Path();
  final _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFF1B1726);
  final _popText = PixelText()..set('pop!', 0xFFFFF6D8, 1);

  /// 전장 좌표 — 처치: 첫 1프레임 흰 번쩍 원 → 흰 충격파 링이 빠르게 퍼지고, 진한 외곽선 파스텔 별·하트·동그라미가 넓게 튀며
  /// 두 번 통통 튄다. 큰 처치(같은 프레임 3마리↑)는 'POP!'(화면에 최대 2개).
  void paint(Canvas c, double now, {required bool lite, bool fever = false}) {
    _paintStars(c, now);
    _pops.removeWhere((p) => now - p.$3 > _popMs);
    var texts = 0;
    for (var i = _pops.length - 1; i >= 0; i--) {
      final (x, y, at, size, loud) = _pops[i];
      final age = now - at;
      final t = age / _popMs;
      if (age < 34) {
        _fill.color = const Color(0xE6FFFFFF);
        c.drawCircle(Offset(x, y), size * 0.9, _fill);
      }
      if (!lite && t < 0.42) _puff(c, x, y, size.toDouble(), t / 0.42);
      if (t < 0.3) {
        final k = t / 0.3;
        _fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - k) + 0.5
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - k);
        c.drawCircle(Offset(x, y), size * (0.6 + 2.6 * (1 - (1 - k) * (1 - k))), _fill);
        _fill.style = PaintingStyle.fill;
      }
      if (loud && !lite && t < 0.6 && texts < 2) {
        texts++;
        final k = t / 0.6;
        final sc = k < 0.3 ? 1.2 + k / 0.3 * 1.3 : 2.5 - (k - 0.3) / 0.7 * 0.6;
        c
          ..save()
          ..translate(x + 6, y - size - 12 - 8 * k)
          ..scale(sc);
        _popText.draw(c, -_popText.width / 2, -2.5);
        c.restore();
      }
      final n = lite ? 4 : (fever ? 14 : 8); // 피버 v2: 파편 거의 2배
      for (var k = 0; k < n; k++) {
        final a = k * 2 * math.pi / n + x * 0.13;
        final d = size * (0.8 + 3.8 * (1 - (1 - t) * (1 - t)));
        // 통통: 높이가 두 번 튐(0~0.55 큰 튐, 0.55~1 작은 튐)
        final hop = t < 0.55 ? math.sin(t / 0.55 * math.pi) * 13 : math.sin((t - 0.55) / 0.45 * math.pi) * 5;
        final p = Offset(x + math.cos(a) * d, y + math.sin(a) * d * 0.8 - hop);
        final sz = (k % 4 == 3 ? 3.4 : 6.0) * (1 - t * 0.45);
        final alpha = t > 0.7 ? (1 - t) / 0.3 : 1.0;
        _shape.reset();
        switch (k % 4) {
          case 0: // 별
            for (var j = 0; j < 10; j++) {
              final r = j.isEven ? sz * 0.9 : sz * 0.4;
              final aa = -math.pi / 2 + j * math.pi / 5 + t * 2;
              final px = p.dx + math.cos(aa) * r;
              final py = p.dy + math.sin(aa) * r;
              j == 0 ? _shape.moveTo(px, py) : _shape.lineTo(px, py);
            }
            _shape.close();
          case 1: // 하트(동그라미 둘 + 아래 꼭짓점)
            _shape
              ..addOval(Rect.fromCircle(center: p + Offset(-sz * 0.24, -sz * 0.1), radius: sz * 0.3))
              ..addOval(Rect.fromCircle(center: p + Offset(sz * 0.24, -sz * 0.1), radius: sz * 0.3))
              ..moveTo(p.dx - sz * 0.52, p.dy)
              ..lineTo(p.dx + sz * 0.52, p.dy)
              ..lineTo(p.dx, p.dy + sz * 0.55)
              ..close();
          default: // 동그라미·금빛 점
            _shape.addOval(Rect.fromCircle(center: p, radius: sz * 0.42));
        }
        if (!lite && _pops.length - i <= 10) {
          // 외곽선은 최근 10개만(200마리 피버에서 그리기 수 상한)
          _outline.color = Color.fromRGBO(27, 23, 38, alpha);
          c.drawPath(_shape, _outline);
        }
        _fill.color = Color(_pastel[(k + size) % _pastel.length]).withValues(alpha: alpha);
        c.drawPath(_shape, _fill);
      }
    }
  }
}
