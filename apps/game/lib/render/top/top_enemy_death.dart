import 'dart:math' as math;
import 'dart:ui';

/// 잡몹 처치 연출 유형(S1 '종류별 처치 연출'): 27종을 7가지로 묶는다. [pop] = 공용(붐빔 모드·모르는 종).
enum DeathType { pop, shell, bloat, fish, bird, bone, spirit, sink }

/// 잡몹 종류별 처치 연출 (S1): 0.3초 — 몸 그림의 자세(위치·회전·배율·투명도)와 조각 입자.
/// - shell(게·불가사리·성게): 뒤집혀 다리 버둥 → 펑 + 주황 조각
/// - bloat(해파리·복어·물총): 부풀었다 터져 물방울
/// - fish(피라냐·날치·아귀·장어·오징어): 튀어 오르며 돌다 반짝 사라짐
/// - bird(갈매기·불새): 깃털 흩날림
/// - bone(해골): 뼈 조각 와르르
/// - spirit(망령·유령 해파리·저주 갈매기): 위로 늘어지며 연기로 흩어짐
/// - sink(거북·물개·펭귄·배·골렘): 작아지며 가라앉고 물 고리·거품
/// 입자는 목록 없이 진행 t와 씨앗으로 계산(결정론·가벼움).
class TopEnemyDeath {
  static const ms = 300.0;

  static DeathType typeOf(String kind) {
    bool has(List<String> keys) => keys.any(kind.contains);
    if (has(const ['wraith', 'ghost', 'curse'])) return DeathType.spirit;
    if (has(const ['skeleton', 'bone'])) return DeathType.bone;
    if (has(const ['crab', 'starfish', 'urchin'])) return DeathType.shell;
    if (has(const ['jelly', 'puffer', 'siphon'])) return DeathType.bloat;
    if (has(const ['piranha', 'flyingfish', 'angler', 'eel', 'squid', 'fish'])) return DeathType.fish;
    if (has(const ['gull', 'bird'])) return DeathType.bird;
    if (has(const ['turtle', 'seal', 'penguin', 'ship', 'pirate', 'sub', 'golem', 'breaker', 'raider'])) {
      return DeathType.sink;
    }
    return DeathType.pop;
  }

  /// 몸 그림 자세: (dx, dy 몸 크기 배수, 가로 배율, 세로 배율, 더할 회전, 투명도). 투명도 0이면 그리지 않는다.
  static (double, double, double, double, double, double) pose(DeathType type, double t) {
    switch (type) {
      case DeathType.shell:
        final flip = math.min(1, t / 0.22);
        final kick = t < 0.65 ? math.sin(t * 70) * 0.18 : 0.0;
        final out = t < 0.65 ? 1.0 : 1 - (t - 0.65) / 0.35;
        final grow = t < 0.65 ? 1.0 : 1 + 0.3 * (t - 0.65) / 0.35;
        return (0, 0, -grow * (1 - 2 * flip).abs().clamp(0.2, 1), grow, math.pi * flip + kick, out);
      case DeathType.bloat:
        final s = 1 + 0.55 * math.min(1, t / 0.6);
        return (0, 0, s, s, 0, t < 0.6 ? 1 : 0);
      case DeathType.fish:
        final arc = math.sin(math.pi * math.min(1, t / 0.85));
        return (
          0.15 * t,
          -0.9 * arc,
          1 + 0.25 * arc,
          1 + 0.25 * arc,
          2 * math.pi * t,
          t < 0.55 ? 1 : 1 - (t - 0.55) / 0.45,
        );
      case DeathType.bird:
        return (
          0,
          -0.2 * t,
          1 - 0.4 * t,
          1 - 0.4 * t,
          0.8 * t,
          t < 0.4 ? 1 - t / 0.4 * 0.6 : math.max(0, 0.4 - (t - 0.4)),
        );
      case DeathType.bone:
        return (0, 0.1 * t, 1, 1 - 0.3 * t, 0, t < 0.3 ? 1 : 0);
      case DeathType.spirit:
        return (0, -0.45 * t, 1 - 0.45 * t, 1 + 0.5 * t, 0, 1 - t);
      case DeathType.sink:
        return (0, 0.1 * t, 1 - 0.6 * t, 1 - 0.6 * t, 0, 1 - t);
      case DeathType.pop:
        final u = math.min(1, t * ms / 160); // 예전 찌그러짐 0.16초
        return (0, 0, 1.25 + 0.35 * u, math.max(0.05, 0.65 * (1 - u)), 0, u < 1 ? 1 : 0);
    }
  }

  /// 사라지는 몸 그림 붓(투명도) — TopEnemies가 쓴다.
  final fade = Paint();
  final _fill = Paint()..isAntiAlias = true;
  final _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// 조각 입자. [at] = 처치 자리, [size] = 몸 크기(전장 단위), [seed] = 개체마다 다른 각도.
  void particles(Canvas c, DeathType type, Offset at, double t, double size, int seed) {
    final r = size * 0.5;
    double ang(int i, int n) => i * 2 * math.pi / n + (seed % 97) * 0.07;
    switch (type) {
      case DeathType.shell:
        if (t < 0.65) return;
        final k = (t - 0.65) / 0.35;
        for (var i = 0; i < 6; i++) {
          final u = Offset(math.cos(ang(i, 6)), math.sin(ang(i, 6)));
          _fill.color = Color.fromRGBO(255, 150, 70, 1 - k);
          c.drawCircle(at + u * r * (0.4 + 1.3 * k), r * 0.16 * (1 - 0.5 * k), _fill);
        }
        _line
          ..strokeWidth = r * 0.12 * (1 - k)
          ..color = Color.fromRGBO(255, 240, 200, 1 - k);
        c.drawCircle(at, r * (0.5 + 0.9 * k), _line);
      case DeathType.bloat:
        if (t < 0.6) return;
        final k = (t - 0.6) / 0.4;
        for (var i = 0; i < 8; i++) {
          final u = Offset(math.cos(ang(i, 8)), math.sin(ang(i, 8)));
          _fill.color = Color.fromRGBO(200, 236, 255, 0.9 * (1 - k));
          c.drawOval(
            Rect.fromCenter(center: at + u * r * (0.6 + 1.4 * k), width: r * 0.36, height: r * 0.46),
            _fill,
          );
        }
        _line
          ..strokeWidth = r * 0.1
          ..color = Color.fromRGBO(220, 245, 255, 0.8 * (1 - k));
        c.drawCircle(at, r * (0.9 + 0.8 * k), _line);
      case DeathType.fish:
        if (t < 0.5) return;
        final k = (t - 0.5) / 0.5;
        final p = at + Offset(r * 0.3, -size * 0.9 * math.sin(math.pi * math.min(1, t / 0.85)));
        final s = r * 0.9 * math.sin(math.pi * k);
        _fill.color = const Color(0xFFFFF6C0);
        c.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - s)
            ..lineTo(p.dx + s * 0.25, p.dy - s * 0.25)
            ..lineTo(p.dx + s, p.dy)
            ..lineTo(p.dx + s * 0.25, p.dy + s * 0.25)
            ..lineTo(p.dx, p.dy + s)
            ..lineTo(p.dx - s * 0.25, p.dy + s * 0.25)
            ..lineTo(p.dx - s, p.dy)
            ..lineTo(p.dx - s * 0.25, p.dy - s * 0.25)
            ..close(),
          _fill,
        );
      case DeathType.bird:
        for (var i = 0; i < 6; i++) {
          final a = ang(i, 6);
          final u = Offset(math.cos(a), math.sin(a));
          final p = at + u * r * (0.3 + 1.2 * t) + Offset(math.sin(t * 12 + i) * r * 0.2, r * 0.6 * t * t);
          c
            ..save()
            ..translate(p.dx, p.dy)
            ..rotate(a + t * 4 * (i.isEven ? 1 : -1));
          _fill.color = Color.fromRGBO(250, 252, 255, 1 - t);
          c
            ..drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.55, height: r * 0.2), _fill)
            ..restore();
        }
      case DeathType.bone:
        if (t < 0.2) return;
        final k = (t - 0.2) / 0.8;
        _line.strokeWidth = r * 0.16;
        for (var i = 0; i < 7; i++) {
          final a = ang(i, 7);
          final p = at + Offset(math.cos(a), math.sin(a) * 0.6) * r * (0.3 + 1.1 * k) + Offset(0, r * 1.4 * k * k);
          final d = Offset(math.cos(a + k * 6), math.sin(a + k * 6)) * r * 0.28;
          _line.color = Color.fromRGBO(240, 236, 220, k < 0.7 ? 1 : (1 - k) / 0.3);
          c.drawLine(p - d, p + d, _line);
        }
      case DeathType.spirit:
        for (var i = 0; i < 5; i++) {
          final a = ang(i, 5);
          final p = at + Offset(math.cos(a) * r * 0.8 * t, -r * (0.2 + 1.2 * t) + math.sin(a) * r * 0.3);
          _fill.color = Color.fromRGBO(170, 150, 210, 0.55 * (1 - t));
          c.drawCircle(p, r * (0.25 + 0.35 * t), _fill);
        }
      case DeathType.sink:
        _line
          ..strokeWidth = r * 0.1 * (1 - t) + 0.5
          ..color = Color.fromRGBO(230, 248, 255, 0.85 * (1 - t));
        c.drawOval(Rect.fromCenter(center: at, width: r * (1.2 + 1.4 * t) * 2, height: r * (1.2 + 1.4 * t)), _line);
        for (var i = 0; i < 4; i++) {
          final a = ang(i, 4);
          _fill.color = Color.fromRGBO(220, 245, 255, 0.8 * (1 - t));
          c.drawCircle(at + Offset(math.cos(a) * r * 0.6, -r * 1.1 * t + math.sin(a) * r * 0.3), r * 0.12, _fill);
        }
      case DeathType.pop:
    }
  }
}
