import 'dart:math' as math;
import 'dart:ui';

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
  final List<(double, double, double, int)> _pops = []; // x, y, ms, 크기
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
  void hit(double now, Offset dir, {required bool strong, required bool shake}) {
    // 멈춤은 강(보스·궁극기)만, 0.6초에 한 번 — 범위·치명마다 멈추면 '몬스터가 다 멈춘다'(사용자 첫 불만)로 돌아간다.
    if (strong && now - _lastFreezeAt >= 600) {
      _freeze = 50;
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

  /// 처치: 그 자리에서 잉크·조각이 튄다([size] = 적 크기 단위).
  void pop(double x, double y, double now, int size) {
    if (_pops.length >= 24) _pops.removeAt(0);
    _pops.add((x, y, now, size));
  }

  void clear() {
    _freeze = 0;
    _knock.clear();
    _pops.clear();
  }

  /// 전장 좌표 — 처치 조각.
  void paint(Canvas c, double now, {required bool lite}) {
    _pops.removeWhere((p) => now - p.$3 > 420);
    for (final (x, y, at, size) in _pops) {
      final t = (now - at) / 420;
      final n = lite ? 4 : 7;
      for (var k = 0; k < n; k++) {
        final a = k * 2 * math.pi / n + x * 0.13;
        final d = size * (0.4 + 1.1 * (1 - (1 - t) * (1 - t)));
        _fill.color = (k.isEven ? const Color(0xFF1E1A26) : const Color(0xFFFFFFFF)).withValues(alpha: 1 - t);
        final s = k.isEven ? 2.5 * (1 - t) + 1 : 1.5;
        c.drawRect(
          Rect.fromCenter(center: Offset(x + math.cos(a) * d, y + math.sin(a) * d), width: s, height: s),
          _fill,
        );
      }
      if (t < 0.3) {
        _fill.color = const Color(0xFF1E1A26).withValues(alpha: 0.5 * (1 - t / 0.3));
        c.drawCircle(Offset(x, y), size * 0.5 * (1 + t), _fill);
      }
    }
  }
}
