import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_species.dart';

/// 쏘기 직전 빛(S1 요청 '쏘는 부위가 밝아짐', S5 EnemyWindup·HdSpecies.muzzle): 엔진 예고(EnemyWindup, 쏘기 약 0.4초 전)부터
/// 쏘는 부위(부리·가시 끝·입 — r 배수, 왼쪽 보기 기준, 없으면 몸 가운데)가 점점 밝아지고, 쏘는 순간(EnemyFired) 확 번쩍 터진 뒤
/// 사라진다. 예고 없이 쏘면(예고 끔·옛 기록) 터짐만. 원거리 잡몹은 작게, 보스(기본 포탄·일제 사격)는 크게. 전장 좌표.
class HdMuzzle {
  final Map<int, _Glow> _glows = {};
  final List<(double, double, double, bool)> _now = []; // x, y, 밝기 0~1, 보스
  final _glow = Paint()
    ..isAntiAlias = true
    ..blendMode = BlendMode.plus;
  static const _burstMs = 180.0;
  static const _lateMs = 400.0; // 예고 뒤 이만큼 늦게까지 못 쏘면(보스 포탄은 몇 틱 늦기도) 사그라든다

  /// 엔진 예고: 적 [id]가 [ms] 뒤 쏜다.
  void windup(int id, double now, double ms, {required bool boss}) {
    _trim(now);
    _glows[id] = _Glow(now, now + ms, boss: boss);
  }

  /// 쐈다 — 차오르던 빛을 터뜨린다(예고가 없었으면 터짐만).
  void fired(int id, double now, {bool boss = false}) {
    _trim(now);
    final g = _glows[id];
    _glows[id] = (g ?? _Glow(now, now, boss: boss))..firedAt = now;
  }

  /// 보스 기본 포탄(BossFired — 적 id가 없다): 차오르던 보스 빛을 모두 터뜨린다.
  void firedBosses(double now) {
    for (final g in _glows.values) {
      if (g.boss && g.firedAt == null) g.firedAt = now;
    }
  }

  void _trim(double now) {
    if (_glows.length > 64) _glows.removeWhere((_, g) => g.done(now));
  }

  /// TopEnemies: 적마다 — 빛나는 중이면 자리를 모은다. [world] = 칸 크기(단위), [right] = 뒤집어 오른쪽 봄.
  void collect(int id, String kind, double x, double y, double world, {required bool right, required double now}) {
    final g = _glows[id];
    if (g == null) return;
    if (g.done(now)) {
      _glows.remove(id);
      return;
    }
    final sp = g.boss ? hdBosses[kind] : hdEnemies[kind];
    final r = world / (2 * (sp?.extent ?? 1.4));
    final m = sp?.muzzle ?? Offset.zero;
    _now.add((x + (right ? -m.dx : m.dx) * r, y + m.dy * r, g.level(now), g.boss));
  }

  /// 적 [id]가 지금 쏘기 직전(예고 중, 아직 안 쏨) — HD v2 보스 '공격 예고' 얼굴.
  bool charging(int id, double now) {
    final g = _glows[id];
    return g != null && g.firedAt == null && !g.done(now);
  }

  /// 예고·터짐 중인 적 수(시험).
  int get active => _glows.length;

  /// 이번 프레임에 모인 빛 수(시험).
  int get pending => _now.length;

  /// 적을 다 그린 뒤 한 번.
  void paint(Canvas c) {
    for (final (x, y, s, boss) in _now) {
      final k = boss ? 2.4 : 1.0;
      _glow.color = Color.fromRGBO(255, 200, 80, 0.5 * s);
      c.drawCircle(Offset(x, y), (3 + 4 * s) * k, _glow);
      _glow.color = Color.fromRGBO(255, 255, 255, 0.9 * s);
      c.drawCircle(Offset(x, y), (1.2 + 1.8 * s) * k, _glow);
    }
    _now.clear();
  }
}

class _Glow {
  _Glow(this.from, this.at, {required this.boss});
  final double from;
  final double at;
  final bool boss;
  double? firedAt;

  bool done(double now) {
    final f = firedAt;
    return f != null ? now - f > HdMuzzle._burstMs : now - at > HdMuzzle._lateMs;
  }

  /// 0~1: 예고 동안 차오름(0.15 → 0.7), 늦으면 사그라듦, 쏘면 1에서 꺼짐.
  double level(double now) {
    final f = firedAt;
    if (f != null) return 1 - (now - f) / HdMuzzle._burstMs;
    final span = at - from;
    if (now <= at) return span <= 0 ? 0.7 : 0.15 + 0.55 * ((now - from) / span).clamp(0.0, 1.0);
    return 0.7 * (1 - (now - at) / HdMuzzle._lateMs);
  }
}
