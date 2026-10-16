import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/sprite_draw.dart';

/// 계열 행동 v3 연출 (S5 family-v3, docs/specs/platform-family-behavior-v3.md, 사용자 승인):
/// - 출격(CrewSortie): 강습·공중 선원 본인(초상 + 등급 색 테)이 배 → 적(out) → 꽂혀 휘두름(strike, 베기는 TopSlash) → 배로(back).
///   공중 계열은 out 동안 하늘로 작아졌다(높이) 급강하한다.
/// - 레이저(AttackFired.beamTicks): 배에 붙은 빔이 그 방향 화면 끝까지, 유지 동안 맥박. 맞는 자리 불꽃은 부르는 쪽(TopImpact).
/// - 집속 자탄(BombletBurst)은 부르는 쪽이 작은 TopImpact로.
class TopFamilyV3 {
  final List<_Flight> _flights = [];
  final List<_Beam> _beams = [];
  final _fill = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// 출격 한 구간. [air] = 공중 계열(높이 곡선), [color] = 등급 색.
  void sortie(
    String crewId,
    String phase,
    Offset from,
    Offset to,
    double startMs,
    double durMs,
    int color, {
    bool air = false,
  }) {
    _flights
      ..removeWhere((f) => f.crewId == crewId)
      ..add(_Flight(crewId, phase, from, to, startMs, math.max(1, durMs), color, air: air));
  }

  /// 레이저: 배 → [dir] 방향, [startMs]부터 [durMs] 동안.
  void beam(String crewId, Offset dir, double startMs, double durMs, int color) {
    _beams
      ..removeWhere((b) => b.crewId == crewId)
      ..add(_Beam(crewId, dir, startMs, math.max(1, durMs), color));
  }

  /// [crewId]의 레이저가 지금 켜져 있는가(맞는 자리 불꽃용).
  bool beaming(String crewId, double now) => _beams.any((b) => b.crewId == crewId && now >= b.ms && now < b.ms + b.dur);

  void clear() {
    _flights.clear();
    _beams.clear();
  }

  /// 전장 좌표. [ship] = 배 중심(빔이 붙는 자리), [view] = 보이는 전장(빔 끝).
  void paint(Canvas c, double now, Offset ship, Rect view, SpriteDraw? sprites) {
    _beams.removeWhere((b) => now > b.ms + b.dur + 120);
    for (final b in _beams) {
      final age = now - b.ms;
      if (age < 0) continue;
      final t = (age / b.dur).clamp(0.0, 1.0);
      final fade = age > b.dur ? 1 - (age - b.dur) / 120 : 1.0;
      final len = view.width + view.height;
      final end = ship + b.dir * len;
      final pulse = 0.85 + 0.15 * math.sin(age / 30);
      final grow = math.min(1, age / 60);
      _line
        ..strokeWidth = 10 * grow * pulse * fade
        ..color = Color(b.color).withValues(alpha: 0.35 * fade);
      c.drawLine(ship, end, _line);
      _line
        ..strokeWidth = 5 * grow * pulse * fade
        ..color = Color(b.color).withValues(alpha: 0.9 * fade);
      c.drawLine(ship, end, _line);
      _line
        ..strokeWidth = 2 * grow * fade
        ..color = const Color(0xFFFFFFFF).withValues(alpha: fade);
      c.drawLine(ship, end, _line);
      // 포구 빛 덩이
      _fill.color = const Color(0xFFFFFFFF).withValues(alpha: 0.8 * fade * (1 - t * 0.3));
      c.drawCircle(ship + b.dir * 10, 5 * pulse, _fill);
    }
    _flights.removeWhere((f) => now > f.ms + f.dur + 50);
    for (final f in _flights) {
      final age = now - f.ms;
      if (age < 0) continue;
      final t = (age / f.dur).clamp(0.0, 1.0);
      final ease = f.phase == 'strike' ? 1.0 : 1 - (1 - t) * (1 - t);
      final from = f.phase == 'back' ? f.to : f.from;
      final to = f.phase == 'back' ? f.from : f.to;
      var at = f.phase == 'strike' ? f.to : Offset.lerp(from, to, ease)!;
      var scale = 1.0;
      if (f.air && f.phase == 'out') {
        // 하늘로 작아졌다 급강하: 앞 60%는 위로(작게), 뒤 40%는 내리꽂음
        final up = t < 0.6 ? math.sin(t / 0.6 * math.pi / 2) : 1 - (t - 0.6) / 0.4;
        scale = 1 - 0.4 * up;
        at = at - Offset(0, 24 * up);
      }
      if (f.phase == 'strike') {
        // 꽂혀 휘두름: 좌우로 흔들기
        at = at + Offset(math.sin(age / 35) * 2.5, 0);
      }
      final r = 11.0 * scale; // 초상이 읽히게(약 23dp)
      // 그림자
      _fill.color = const Color(0x401B1726);
      c.drawOval(
        Rect.fromCenter(
          center: f.phase == 'strike' ? f.to : Offset.lerp(from, to, ease)!,
          width: r * 1.8,
          height: r * 0.8,
        ),
        _fill,
      );
      // 등급 색 테 + 초상
      _fill.color = Color(f.color);
      c.drawCircle(at, r + 1.6, _fill);
      // 초상: 큰 그림(portrait:) 먼저, 없으면 작은 아이콘(crew:).
      final key = sprites?.sheet('portrait:${f.crewId}') != null ? 'portrait:${f.crewId}' : 'crew:${f.crewId}';
      if (sprites != null && sprites.sheet(key) != null) {
        c
          ..save()
          ..clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: r)));
        sprites.draw(c, key, at.dx, at.dy, w: r * 2.2, h: r * 2.2);
        c.restore();
      } else {
        _fill.color = const Color(0xFFFFFFFF);
        c.drawCircle(at, r, _fill);
      }
      // 이동 잔상
      if (f.phase != 'strike') {
        final dir = to - from;
        final len = dir.distance;
        if (len > 1) {
          final u = dir / len;
          for (var k = 1; k <= 3; k++) {
            _fill.color = Color(f.color).withValues(alpha: 0.35 / k);
            c.drawCircle(at - u * (k * 5.0), r * (1 - k * 0.15), _fill);
          }
        }
      }
    }
  }
}

class _Flight {
  _Flight(this.crewId, this.phase, this.from, this.to, this.ms, this.dur, this.color, {required this.air});
  final String crewId;
  final String phase;
  final Offset from;
  final Offset to;
  final double ms;
  final double dur;
  final int color;
  final bool air;
}

class _Beam {
  _Beam(this.crewId, this.dir, this.ms, this.dur, this.color);
  final String crewId;
  final Offset dir;
  final double ms;
  final double dur;
  final int color;
}
