import 'dart:math' as math;
import 'dart:ui';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';

/// 선원 특성 연출 (S2 crew-traits, 사용자 2026-10-17): 엔진은 새 이벤트 없이 같은 선원의 Damage를 순서대로 낸다.
/// - 연쇄 번개(arc.counts, pelly): 한 틱 그 선원의 맞은 적들을 순서대로 지그재그 번개가 50ms씩 튐 — 등급별 색·굵기, 마지막 적 작은 폭발.
/// - 처형(execute, bones): 처형 기준 HP 아래 적 머리 위 붉은 X 표식, 처형 피해(같은 적 두 번째 Damage)엔 붉은 X 베기.
/// - 충전 사격(charge, volt): 같은 적 두 번째 Damage = 충전 일격 — 하늘색 전기 구슬이 터지며 번개 가시.
/// - 추적 깃털(noMiss, polly): 발사체가 옆으로 휘며 따라감([curveFor]).
class TopTraits {
  TopTraits(this._t);
  final GameTables _t;

  late final int _legendRarity = _t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  final Map<(String, int), LegendDef?> _cache = {};

  LegendDef? legendOf(String crewId, int rarity) =>
      _cache.putIfAbsent((crewId, rarity), () => _t.skills.legendFor(crewId, rarity, _legendRarity));

  final List<_Chain> _chains = [];
  final List<(Offset, double, bool)> _bursts = []; // 자리, ms, 처형(아니면 충전)
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = false;
  final _fill = Paint()..isAntiAlias = false;
  final _bolt = Path();

  static const _hopMs = 50.0;
  static const _boltMs = 220.0;
  static const _burstMs = 320.0;
  static const _rarityColors = [0xFFE6F6FF, 0xFF7FD8FF, 0xFFC08CFF, 0xFFFFD24A, 0xFFFF6FB5];

  /// 추적 깃털이면 발사체를 옆으로 휘게(단위, 좌우 번갈아), 아니면 0.
  double curveFor(String crewId, int rarity, int salt) {
    final l = legendOf(crewId, rarity);
    if (l == null || !(l.noMiss || l.noMissChance > 0)) return 0;
    return salt.isEven ? 22 : -22;
  }

  /// 한 틱의 Damage들을 보고 연쇄·처형·충전을 찾는다.
  void onTick(RecordedTick tick, int index, RecordingPlayer player, double now) {
    final byCrew = <String, List<Damage>>{};
    for (final e in tick.events) {
      if (e is Damage && e.crewId != null) (byCrew[e.crewId!] ??= []).add(e);
    }
    if (byCrew.isEmpty) return;
    for (final slot in tick.frame.fleet) {
      final hits = byCrew[slot.crewId];
      if (hits == null) continue;
      final l = legendOf(slot.crewId, slot.rarity);
      if (l == null) continue;
      Offset? at(int id) {
        final p = player.enemyAt(index, id) ?? player.enemyAt(index - 1, id);
        return p == null ? null : Offset(p.x, p.y);
      }

      if (l.arc?.counts != null && hits.length >= 2) {
        final pts = [for (final d in hits) ?at(d.targetId)];
        if (pts.length >= 2 && _chains.length < 8) _chains.add(_Chain(pts, slot.rarity, now));
      }
      if (l.execute != null || l.charge != null) {
        final seen = <int>{};
        for (final d in hits) {
          if (!seen.add(d.targetId)) {
            final p = at(d.targetId);
            if (p != null && _bursts.length < 16) _bursts.add((p, now, l.execute != null));
          }
        }
      }
    }
  }

  /// 처형 기준(HP 비율) — 함대에 처형 선원이 있으면 그 값, 없으면 0.
  double executeBelow(BattleView frame) {
    for (final s in frame.fleet) {
      final ex = legendOf(s.crewId, s.rarity)?.execute;
      if (ex != null) return ex.below;
    }
    return 0;
  }

  void clear() {
    _chains.clear();
    _bursts.clear();
  }

  /// 적 위 층(전장 좌표). [poses]는 처형 표식용.
  void paint(Canvas c, double now, BattleView frame, List<EnemyPose> poses, int poseCount, {required bool lite}) {
    final below = executeBelow(frame);
    if (below > 0) {
      _line
        ..strokeWidth = 1.6
        ..color = const Color(0xFFFF3A3A);
      for (var k = 0; k < poseCount; k++) {
        final e = poses[k];
        if (e.hpRatio <= 0 || e.hpRatio >= below) continue;
        final p = Offset(e.drawX, e.drawY - 9);
        c
          ..drawLine(p + const Offset(-2.5, -2.5), p + const Offset(2.5, 2.5), _line)
          ..drawLine(p + const Offset(2.5, -2.5), p + const Offset(-2.5, 2.5), _line);
      }
    }
    _chains.removeWhere((ch) => now - ch.at > ch.pts.length * _hopMs + _boltMs + 200);
    for (final ch in _chains) {
      final color = ch.rarity >= 4
          ? Color(_rarityColors[((now / 60).floor()) % 4 + 1])
          : Color(_rarityColors[ch.rarity.clamp(0, 3)]);
      for (var i = 0; i + 1 < ch.pts.length; i++) {
        final t = (now - ch.at - i * _hopMs) / _boltMs;
        if (t < 0 || t >= 1) continue;
        final a = ch.pts[i];
        final b = ch.pts[i + 1];
        _bolt
          ..reset()
          ..moveTo(a.dx, a.dy);
        final n = Offset(-(b.dy - a.dy), b.dx - a.dx) / math.max(1, (b - a).distance);
        for (var k = 1; k < 5; k++) {
          final p = Offset.lerp(a, b, k / 5)!;
          final j = ((i * 7 + k * 13 + (now / 40).floor()) % 9 - 4).toDouble();
          _bolt.lineTo(p.dx + n.dx * j, p.dy + n.dy * j);
        }
        _bolt.lineTo(b.dx, b.dy);
        final fade = 1 - t;
        _line
          ..strokeWidth = (2.5 + ch.rarity * 0.9) * fade + 1
          ..color = color.withValues(alpha: fade);
        c.drawPath(_bolt, _line);
        _line
          ..strokeWidth = 1
          ..color = Color.fromRGBO(255, 255, 255, fade);
        c.drawPath(_bolt, _line);
        // 맞은 적 하얀 번쩍 + 작은 스파크
        _fill.color = Color.fromRGBO(255, 255, 255, 0.8 * fade);
        c.drawCircle(b, 4 * fade + 1, _fill);
      }
      // 마지막 적 작은 폭발
      final last = ch.pts.last;
      final t = (now - ch.at - (ch.pts.length - 1) * _hopMs) / (_boltMs + 100);
      if (t > 0 && t < 1) {
        _line
          ..strokeWidth = 2 * (1 - t) + 0.5
          ..color = color.withValues(alpha: 1 - t);
        c.drawCircle(last, 4 + 14 * t, _line);
        if (!lite) {
          _fill.color = color.withValues(alpha: 1 - t);
          for (var k = 0; k < 6; k++) {
            final a = k * math.pi / 3;
            c.drawRect(
              Rect.fromCenter(center: last + Offset(math.cos(a), math.sin(a)) * (6 + 12 * t), width: 2, height: 2),
              _fill,
            );
          }
        }
      }
    }
    _bursts.removeWhere((b) => now - b.$2 > _burstMs);
    for (final (p, at, exec) in _bursts) {
      final t = (now - at) / _burstMs;
      if (exec) {
        // 붉은 X 베기: 두 줄이 빠르게 그어지고 사라짐
        final k = math.min<double>(1, t * 3);
        _line
          ..strokeWidth = 3 * (1 - t) + 1
          ..color = Color.fromRGBO(255, 50, 50, 1 - t);
        c
          ..drawLine(p + const Offset(-9, -9), p + Offset(-9 + 18 * k, -9 + 18 * k), _line)
          ..drawLine(p + const Offset(9, -9), p + Offset(9 - 18 * k, -9 + 18 * k), _line);
      } else {
        // 충전 일격: 하늘색 전기 구슬 + 번개 가시 6개
        _fill.color = Color.fromRGBO(140, 220, 255, 0.7 * (1 - t));
        c.drawCircle(p, 6 + 10 * t, _fill);
        _line
          ..strokeWidth = 1.5
          ..color = Color.fromRGBO(230, 250, 255, 1 - t);
        for (var k = 0; k < 6; k++) {
          final a = k * math.pi / 3 + t * 2;
          final r = 8 + 14 * t;
          c.drawLine(
            p + Offset(math.cos(a), math.sin(a)) * r * 0.4,
            p + Offset(math.cos(a + 0.3), math.sin(a + 0.3)) * r,
            _line,
          );
        }
      }
    }
  }
}

class _Chain {
  _Chain(this.pts, this.rarity, this.at);
  final List<Offset> pts;
  final int rarity;
  final double at;
}
