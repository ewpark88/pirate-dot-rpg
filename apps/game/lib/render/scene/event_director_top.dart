part of 'event_director.dart';

/// 탑다운 배 피격 번쩍 길이(부딪힘이 보이게, S1).
const _kTopHitFlashMs = 110.0;

/// 탑다운 전용 연출 도우미 (event_director 300줄 한도로 나눔).
extension _TopEvents on EventDirector {
  /// 탑다운 발사 임팩트: 포구 섬광(쏜 선원의 등급 색)·고리·연기 — 발사체가 실제로 떠나는 시각에.
  void _topMuzzle(AttackFired e, BattleView frame, Offset tip, double start) {
    var rarity = 0;
    for (final s in frame.fleet) {
      if (s.crewId == e.crewId) rarity = s.rarity;
    }
    final colors = scene.tables.rarities.rarities;
    final color = parseArgb(colors[rarity.clamp(0, colors.length - 1)].color, 'rarities.color');
    final delayMs = math.max<double>(0, (start - _player.position) * _player.tickMs / math.max(1, frame.speed));
    scene.topHits.muzzle(
      tip.dx,
      tip.dy,
      math.atan2(e.y - tip.dy, e.x - tip.dx),
      color,
      e.crewId,
      scene.clockMs + delayMs,
    );
  }

  /// 배 피해 숫자 자리: 탑다운은 맞은 쪽 선체 위(작게, 빨강), 옆모습은 배 위.
  Offset _shipNumberAt(ShipDamaged e) {
    final c = scene.shipCenter;
    if (!scene.isTop || e.fromX == null || e.fromY == null) return Offset(c.dx, c.dy - kShipHeight / 2 - kNumberLiftPx);
    final side = (e.fromX! - c.dx).clamp(-10.0, 10.0);
    return Offset(c.dx + side, c.dy - 22);
  }
}
