part of 'event_director.dart';

/// 계열 행동 v3·돌격대·상위 착탄 연출 도우미 (event_director_top 300줄로 나눔).
extension _FamilyEvents on EventDirector {
  int _rarityColor(BattleView frame, String crewId) {
    var rarity = 0;
    for (final s in frame.fleet) {
      if (s.crewId == crewId) rarity = s.rarity;
    }
    final colors = scene.tables.rarities.rarities;
    return parseArgb(colors[rarity.clamp(0, colors.length - 1)].color, 'rarities.color');
  }

  /// 출격형 공격(같은 틱 CrewSortie out)이면 탄을 그리지 않는다 — 선원 초상이 날아간다(S5 family-v3).
  bool _sortieShot(RecordedTick tick, String crewId) =>
      scene.isTop && tick.events.any((x) => x is CrewSortie && x.crewId == crewId && x.phase == 'out');

  /// 출격 한 구간(out·strike·back): 초상이 날아가고, strike면 휘두르기 호(TopSlash)도.
  void _sortie(CrewSortie e, BattleView frame) {
    final color = _rarityColor(frame, e.crewId);
    final dur = e.ticks * _player.tickMs / math.max(1, frame.speed);
    final from = Offset(e.fromX, e.fromY);
    final to = Offset(e.toX, e.toY);
    scene.topHits.family.sortie(
      e.crewId,
      e.phase,
      from,
      to,
      scene.clockMs,
      dur,
      color,
      air: _crewFamily[e.crewId] == 'air',
    );
    if (e.phase == 'strike') scene.topHits.slash.swing(e.toX, e.toY + 12, e.toX, e.toY, scene.clockMs, color);
  }

  /// 레이저(AttackFired.beamTicks): 배에 붙은 빔, 쏜 틱부터 유지.
  void _beam(AttackFired e, int index, BattleView frame) {
    final ship = scene.topShip;
    final d = Offset(e.x, e.y) - ship;
    final len = d.distance;
    final speed = math.max(1, frame.speed);
    final delayMs = math.max<double>(0, (index - _player.position) * _player.tickMs / speed);
    scene.topHits.family.beam(
      e.crewId,
      len < 1e-6 ? const Offset(0, -1) : d / len,
      scene.clockMs + delayMs,
      e.beamTicks! * _player.tickMs / speed,
      _rarityColor(frame, e.crewId),
    );
    _flashSlot(frame, e.crewId);
  }

  /// 전설 상위·신화 단일형 착탄 폭발(AttackFired.splashRadius, S5): 엔진 반경 그대로, 피해 시각([impact] 틱)에 터진다.
  /// 신화는 무지개 충격파. 등급 색 = 쏜 선원.
  void _splash(AttackFired e, double impact, BattleView frame) {
    var rarity = 0;
    for (final s in frame.fleet) {
      if (s.crewId == e.crewId) rarity = s.rarity;
    }
    final colors = scene.tables.rarities.rarities;
    final color = parseArgb(colors[rarity.clamp(0, colors.length - 1)].color, 'rarities.color');
    final delayMs = math.max<double>(0, (impact - _player.position) * _player.tickMs / math.max(1, frame.speed));
    scene.topHits.impact.addFamily(e.family, e.x, e.y, e.splashRadius!, color, rarity, scene.clockMs + delayMs);
  }

  bool _vanguardAt(double x, double y) {
    for (var k = 0; k < scene.poseCount; k++) {
      final p = scene.poses[k];
      if (p.vanguard && (p.x - x).abs() < 4 && (p.y - y).abs() < 4) return true;
    }
    return false;
  }
}
