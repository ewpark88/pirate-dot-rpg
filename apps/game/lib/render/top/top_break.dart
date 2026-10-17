import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/top/top_label.dart';

/// 보스 브레이크 쓰러짐 (사용자 '보스 브레이크가 잘 안 보여', BossBroken): 깨지는 순간 노란·흰 충격파 두 겹과 유리 조각,
/// 'BREAK!' 도장(크게 찍혔다가 자리 잡음), 쓰러진 동안 보스가 기우뚱 흔들리고 머리 위로 별이 빙빙 돈다.
/// 그동안 보스 피해 숫자는 치명 크기로(EventDirector). 전장 좌표.
class TopBreak {
  int _id = -1;
  double _at = -1000000000;
  double _ms = 0;
  Offset _pos = Offset.zero;

  final _fill = Paint()..isAntiAlias = false;
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  final _label = TopLabel();
  final _shard = Path();

  /// 쓰러진 보스 그림 반지름(TopMarks가 체력 막대를 그릴 때 알려 준다) — 별·도장을 막대 위로.
  double radius = 28;

  /// 도장 문구(UI가 TopTexts.bossBreak로 채운다).
  String text = 'BREAK!';

  static const _ringMs = 520.0;
  static const _stampMs = 1300.0;

  /// 보스 [id]가 ([x],[y])에서 [ms] 동안 쓰러졌다.
  void broken(int id, double x, double y, double ms, double now) {
    _id = id;
    _at = now;
    _ms = ms;
    _pos = Offset(x, y);
  }

  /// 지금 쓰러져 있나.
  bool isDown(int id, double now) => id == _id && now - _at < _ms;

  /// 쓰러진 보스의 기울기(라디안): 확 기울었다가 천천히 흔들리며, 끝 0.3초에 바로 선다.
  double tiltOf(int id, double now) {
    if (!isDown(id, now)) return 0;
    final age = now - _at;
    final fall = math.min<double>(1, age / 160);
    final rise = math.min<double>(1, (_ms - age) / 300);
    return (0.32 * fall + 0.08 * math.sin(age / 130)) * rise;
  }

  void clear() {
    _id = -1;
    _at = -1000000000;
  }

  /// 보스 위 층: 충격파·조각·별·도장. [bossAt]은 지금 보스 자리(움직이면 따라감).
  void paint(Canvas c, double now, Offset? Function(int id) bossAt, {required bool flash, required bool lite}) {
    final age = now - _at;
    if (age < 0 || age > math.max(_ms, _stampMs)) return;
    final at = bossAt(_id) ?? _pos;
    // 충격파 두 겹(노랑 굵게 → 흰 얇게)
    for (var k = 0; k < 2; k++) {
      final t = (age - k * 120) / _ringMs;
      if (t < 0 || t >= 1) continue;
      final e = 1 - (1 - t) * (1 - t);
      _ring
        ..strokeWidth = (k == 0 ? 5 : 2) * (1 - t) + 1
        ..color = k == 0
            ? Color.fromRGBO(255, 214, 60, (flash ? 1 : 0.7) * (1 - t))
            : Color.fromRGBO(255, 255, 255, 0.8 * (1 - t));
      c.drawCircle(at, 14 + 64 * e, _ring);
    }
    // 유리 조각: 노랑·흰 삼각이 돌며 튄다
    if (age < 600) {
      final t = age / 600;
      for (var k = 0; k < (lite ? 8 : 16); k++) {
        final a = k * 2.4 + 0.3;
        final d = 10 + 60 * (1 - (1 - t) * (1 - t)) * (0.6 + 0.4 * (k % 3) / 2);
        final p = at + Offset(math.cos(a) * d, math.sin(a) * d + 30 * t * t);
        final s = 3.0 - 1.5 * t;
        final rot = a + t * 8;
        _shard
          ..reset()
          ..moveTo(p.dx + math.cos(rot) * s * 1.6, p.dy + math.sin(rot) * s * 1.6)
          ..lineTo(p.dx + math.cos(rot + 2.3) * s, p.dy + math.sin(rot + 2.3) * s)
          ..lineTo(p.dx + math.cos(rot + 3.9) * s, p.dy + math.sin(rot + 3.9) * s)
          ..close();
        _fill.color = (k.isEven ? const Color(0xFFFFE24A) : const Color(0xFFFFFFFF)).withValues(alpha: 1 - t);
        c.drawPath(_shard, _fill);
      }
    }
    // 쓰러진 동안 머리 위 별 빙빙
    if (age < _ms) {
      final rise = math.min<double>(1, (_ms - age) / 300);
      for (var k = 0; k < 5; k++) {
        final a = age / 260 + k * 2 * math.pi / 5;
        final p = at + Offset(math.cos(a) * (radius * 0.6 + 6), -radius * 0.8 + math.sin(a) * 6);
        final s = (math.sin(a) > 0 ? 2.0 : 1.5) * rise;
        _fill.color = Color.fromRGBO(255, 230, 80, rise);
        c
          ..drawRect(Rect.fromCenter(center: p, width: s * 3, height: s), _fill)
          ..drawRect(Rect.fromCenter(center: p, width: s, height: s * 3), _fill);
      }
    }
    // 'BREAK!' 도장: 2.2배로 찍혔다가 150ms에 자리, 끝 0.3초에 사라짐
    if (age < _stampMs) {
      final k = math.min<double>(1, age / 150);
      final size = 22 * (2.2 - 1.2 * (1 - (1 - k) * (1 - k)));
      final fade = age > _stampMs - 300 ? (_stampMs - age) / 300 : 1.0;
      c
        ..save()
        ..translate(at.dx, at.dy - radius - 26)
        ..rotate(-0.08);
      _label.draw(c, text, Offset.zero, size, alpha: fade, color: const Color(0xFFFF8A2A));
      c.restore();
    }
  }
}
