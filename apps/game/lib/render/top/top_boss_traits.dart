import 'dart:math' as math;
import 'dart:ui';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';

/// 보스 특성 연출 (S2 boss-traits — 회피·장갑·재생·반사막·분노·호위·가속). 전장 좌표.
/// - 회피(AttackMissed reason evade): 보스 옆으로 하얀 잔상 호 세 줄(MISS 글자는 TopCrewFx가 이미 띄운다).
/// - 장갑(armor, 이벤트 없음): 그 보스가 맞을 때 '팅' — 회색·흰 쇠 불꽃.
/// - 재생(regen, 이벤트 없음): 보스 체력이 오른 프레임마다 초록 '+' 입자가 솟는다.
/// - 반사막(BossTraitFired reflect): 예고 동안 육각 테두리가 깜빡이고, 켜지면 육각 막 + 가장자리에서 튕기는 불꽃.
/// - 분노(enrage): 그 뒤로 붉은 오라 맥박 + 눈 빛(보스 크기 8% 키움은 [enraged]로 TopEnemies가).
/// - 호위(escort): 소환 순간 보스 둘레 물보라 고리, 그 뒤 점선 호위 원.
/// - 가속(dash): 시작에 물거품이 터지며 사라지듯, 동안 물보라 꼬리, 끝에 다시 물보라.
class TopBossTraits {
  TopBossTraits(this._t);
  final GameTables _t;

  final Map<int, (double, double)> _reflect = {}; // 보스 id → (켜짐 ms, 끝 ms) — 켜짐 전은 예고
  final Map<int, (double, double)> _dash = {};
  final Set<int> _enraged = {};
  final Map<int, double> _escort = {};
  final List<(Offset, double, int)> _sparks = []; // 자리, ms, 종류(0 장갑·1 회피·2 재생)
  final Map<int, double> _lastHp = {};

  final _fill = Paint()..isAntiAlias = false;
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  final _hex = Path();

  /// 분노한 보스(TopEnemies가 8% 크게).
  bool enraged(int id) => _enraged.contains(id);

  void fired(BossTraitFired e, double tickMs, double now) {
    final ms = e.ticks * tickMs;
    switch (e.trait) {
      case 'reflect':
        // ticks = 예고 + 지속 — 예고는 엔진 warnSec(대략 앞 1/3)로 본다.
        _reflect[e.enemyId] = (now + ms * 0.3, now + ms);
      case 'dash':
        _dash[e.enemyId] = (now, now + ms);
      case 'enrage':
        _enraged.add(e.enemyId);
      case 'escort':
        _escort[e.enemyId] = now;
    }
  }

  void evade(double x, double y, double now) {
    if (_sparks.length < 24) _sparks.add((Offset(x, y), now, 1));
  }

  /// 한 틱: 장갑 보스 피격 '팅'.
  void onTick(RecordedTick tick, int index, RecordingPlayer player, double now) {
    for (final e in tick.events) {
      if (e is! Damage) continue;
      final p = player.enemyAt(index, e.targetId) ?? player.enemyAt(index - 1, e.targetId);
      if (p == null || !p.boss) continue;
      if (_t.regions.bosses[p.kind]?.trait('armor') == null) continue;
      if (_sparks.length < 24) _sparks.add((Offset(p.x, p.y), now, 0));
    }
  }

  void clear() {
    _reflect.clear();
    _dash.clear();
    _enraged.clear();
    _escort.clear();
    _sparks.clear();
    _lastHp.clear();
  }

  void paint(Canvas c, double now, List<EnemyPose> poses, int poseCount, double Function(EnemyPose) radiusOf) {
    for (var k = 0; k < poseCount; k++) {
      final e = poses[k];
      if (!e.boss) continue;
      final at = Offset(e.drawX, e.drawY);
      final r = radiusOf(e);
      // 재생: 체력이 오르면 초록 '+'
      final prev = _lastHp[e.id];
      _lastHp[e.id] = e.hpRatio;
      if (prev != null && e.hpRatio > prev + 1e-4 && _sparks.length < 24) {
        _sparks.add((at + Offset(((now / 37) % 2 - 1) * r * 0.6, 0), now, 2));
      }
      if (_enraged.contains(e.id)) {
        final pulse = 0.5 + 0.5 * math.sin(now / 140);
        _fill.color = Color.fromRGBO(255, 40, 30, 0.18 + 0.14 * pulse);
        c.drawCircle(at, r * (1.05 + 0.1 * pulse), _fill);
        _fill.color = const Color.fromRGBO(255, 90, 60, 0.9);
        for (final s in const [-1.0, 1.0]) {
          c.drawCircle(at + Offset(s * r * 0.22, -r * 0.35), 1.6 + pulse, _fill);
        }
      }
      final rf = _reflect[e.id];
      if (rf != null && now < rf.$2) {
        final warn = now < rf.$1;
        if (!warn || (now / 120).floor().isEven) _hexShield(c, at, r * 1.15, warn, now);
        if (!warn && (now / 90).floor() % 3 == 0) {
          final a = (now / 53) % (2 * math.pi);
          final p = at + Offset(math.cos(a), math.sin(a)) * r * 1.15;
          _line
            ..strokeWidth = 1.5
            ..color = const Color(0xFFBFF3FF);
          c.drawLine(p, p + Offset(math.cos(a), math.sin(a)) * 8, _line);
        }
      }
      final es = _escort[e.id];
      if (es != null) {
        final t = (now - es) / 500;
        if (t < 1) {
          _line
            ..strokeWidth = 3 * (1 - t) + 1
            ..color = Color.fromRGBO(220, 245, 255, 1 - t);
          c.drawCircle(at, r * (1.2 + 0.8 * t), _line);
        }
        _line
          ..strokeWidth = 1
          ..color = const Color(0x88FFE27A);
        for (var i = 0; i < 16; i++) {
          if (i.isOdd) continue;
          c.drawArc(
            Rect.fromCircle(center: at, radius: r * 1.55),
            i * math.pi / 8 + now / 2000,
            math.pi / 8,
            false,
            _line,
          );
        }
      }
      final da = _dash[e.id];
      if (da != null && now < da.$2 + 400) {
        final t = (now - da.$1) / math.max(1, da.$2 - da.$1);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + now / 200;
          final d = r * (0.6 + 0.3 * math.sin(now / 90 + i));
          _fill.color = Color.fromRGBO(230, 248, 255, t < 1 ? 0.7 : (1 - (now - da.$2) / 400) * 0.7);
          c.drawCircle(at + Offset(math.cos(a), math.sin(a)) * d, 2.5, _fill);
        }
      }
    }
    _sparks.removeWhere((s) => now - s.$2 > 420);
    for (final (at, ms, kind) in _sparks) {
      final t = (now - ms) / 420;
      switch (kind) {
        case 0: // 장갑 '팅': 회색·흰 쇠 불꽃 방사
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3 + at.dx;
            _line
              ..strokeWidth = 1.5
              ..color = (i.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFB8C0CC)).withValues(alpha: 1 - t);
            c.drawLine(
              at + Offset(math.cos(a), math.sin(a)) * (4 + 10 * t),
              at + Offset(math.cos(a), math.sin(a)) * (8 + 14 * t),
              _line,
            );
          }
        case 1: // 회피 잔상: 옆으로 흰 호 세 줄
          _line
            ..strokeWidth = 2
            ..color = Color.fromRGBO(255, 255, 255, 0.7 * (1 - t));
          for (var i = 0; i < 3; i++) {
            c.drawArc(Rect.fromCircle(center: at + Offset(-8.0 - i * 6, 0), radius: 14), -0.9, 1.8, false, _line);
          }
        default: // 재생 '+'
          final p = at + Offset(0, -10 - 20 * t);
          _fill.color = Color.fromRGBO(90, 255, 120, 1 - t);
          c
            ..drawRect(Rect.fromCenter(center: p, width: 7, height: 2), _fill)
            ..drawRect(Rect.fromCenter(center: p, width: 2, height: 7), _fill);
      }
    }
  }

  void _hexShield(Canvas c, Offset at, double r, bool warn, double now) {
    _hex.reset();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + math.pi / 6;
      final p = at + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? _hex.moveTo(p.dx, p.dy) : _hex.lineTo(p.dx, p.dy);
    }
    _hex.close();
    if (!warn) {
      _fill.color = const Color(0x3384E8FF);
      c.drawPath(_hex, _fill);
    }
    _line
      ..strokeWidth = warn ? 1.5 : 2.5
      ..color = warn ? const Color(0xCCFFFFFF) : const Color(0xFF84E8FF);
    c.drawPath(_hex, _line);
    if (!warn) {
      // 안쪽 작은 육각 무늬
      _line
        ..strokeWidth = 1
        ..color = const Color(0x6684E8FF);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + now / 1500;
        c.drawCircle(at + Offset(math.cos(a), math.sin(a)) * r * 0.55, r * 0.22, _line);
      }
    }
  }
}
