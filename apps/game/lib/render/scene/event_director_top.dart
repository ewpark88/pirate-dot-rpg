part of 'event_director.dart';

/// 탑다운 배 피격 번쩍 길이(부딪힘이 보이게, S1).
const _kTopHitFlashMs = 110.0;

/// 보스 포탄 비행 시간(ms) — 미리보기 틱(lookahead) 안에서.
const _bossFlightMs = 650.0;

/// 빠른 강화 부위 흰빛(ms).
const _partUpGlowMs = 300.0;

/// 근접 계열 — 탑다운은 발사체 대신 휘두르기(TopSlash).
const _assault = 'assault';

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

  /// 보스 포탄(BossFired): 엔진 피해 시각(index)에 배에 닿도록 비행 시간만큼 앞서 띄운다. 색은 보스 모양 색(fx bossLook).
  void _bossShot(BossFired e, int index, BattleView frame) {
    final tickMs = _player.tickMs;
    final flightTicks = math.min(_bossFlightMs / tickMs, _juice.lookaheadTicks.toDouble());
    final speed = math.max(1, frame.speed);
    final delayMs = math.max<double>(0, (index - flightTicks - _player.position) * tickMs / speed);
    var color = 0xFFFF5030;
    for (final v in frame.enemies) {
      if (v.boss) color = scene.looks.bossOf(v.kind, boss: true)?.color ?? color;
    }
    final ship = scene.topShip;
    final dx = e.x - ship.dx;
    final dy = e.y - ship.dy;
    final len = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
    // 선체 가장자리(배 중심에서 보스 쪽으로 10단위)에 떨어진다.
    scene.topHits.shots.fire(
      e.x,
      e.y,
      ship.dx + dx / len * 10,
      ship.dy + dy / len * 10,
      scene.clockMs + delayMs,
      flightTicks * tickMs / speed,
      color,
    );
  }

  /// 빠른 강화 한 번(PartUpgraded — UI가 '+대포 Lv 53'을 띄움, S4·S1): 그 부위 흰빛 0.3초 + 배로 올라오는 금빛 줄기.
  /// 단계가 바뀌는 큰 축하(ShipLookChanged)가 진행 중이면 그것을 끊지 않는다.
  void _partUp(String part) {
    final m = scene.moments;
    if (m.glowMs <= 0 || m.glowPart == part) {
      m
        ..glowPart = part
        ..glowMs = math.max(m.glowMs, _partUpGlowMs);
    }
    scene.topHits.upgradeAt = scene.clockMs;
  }

  /// 원거리 적 탄(EnemyFired, S5 위협): 쏜 자리 → 선체 가장자리, flightTicks 뒤 ShipDamaged와 같은 시각에 닿는다. 작은 탄, 색은 종류별.
  void _enemyShot(EnemyFired e, BattleView frame) {
    final speed = math.max(1, frame.speed);
    final ship = scene.topShip;
    final dx = e.fromX - ship.dx;
    final dy = e.fromY - ship.dy;
    final len = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
    final color = _enemyShotColors[e.kind] ?? 0xFFFFFFFF;
    scene.topHits.shots.fire(
      e.fromX,
      e.fromY,
      ship.dx + dx / len * 10,
      ship.dy + dy / len * 10,
      scene.clockMs,
      e.flightTicks * _player.tickMs / speed,
      color,
      big: false,
    );
  }

  /// 솟아오르기 예고(EnemyEmerging): warnTicks 동안 물보라, 끝나면 터짐(몸은 EnemyPose.emerging 동안 숨김).
  void _emerging(EnemyEmerging e, BattleView frame) {
    scene.topHits.emerge(e.x, e.y, scene.clockMs, e.warnTicks * _player.tickMs / math.max(1, frame.speed));
  }

  /// 강습(assault) 탑다운: 발사체 대신 피해 순간(index)에 배에서 대상마다 휘두르기 + 베기 자국. 색 = 쏜 선원 등급 색.
  void _topMelee(AttackFired e, int index, BattleView frame) {
    var rarity = 0;
    for (final s in frame.fleet) {
      if (s.crewId == e.crewId) rarity = s.rarity;
    }
    final colors = scene.tables.rarities.rarities;
    final color = parseArgb(colors[rarity.clamp(0, colors.length - 1)].color, 'rarities.color');
    final delayMs = math.max<double>(0, (index - _player.position) * _player.tickMs / math.max(1, frame.speed));
    final ship = scene.topShip;
    final targets = e.targetIds.isEmpty ? const [-1] : e.targetIds;
    for (final id in targets.take(6)) {
      final t = id < 0 ? null : _player.enemyAt(index, id) ?? _player.enemyAt(index - 1, id);
      scene.topHits.slash.swing(ship.dx, ship.dy, t?.x ?? e.x, t?.y ?? e.y, scene.clockMs + delayMs, color);
    }
    _flashSlot(frame, e.crewId);
  }

  /// 보스 행동 v2(BossPatternShown): warn → 예고 그림, act → 동작(돌진 자국·장판 폭발 + 큰 흔들림), cancel → 지움.
  void _bossPattern(BossPatternShown e, BattleView frame) {
    final b = scene.topHits.boss;
    final now = scene.clockMs;
    switch (e.phase) {
      case 'warn':
        final warnMs = e.warnTicks * _player.tickMs / math.max(1, frame.speed);
        b.warn(e.enemyId, e.kind, e.x, e.y, e.angle, e.count, e.radius, now, warnMs);
      case 'act':
        b.act(e.enemyId, now);
        if (e.kind == 'blast' || e.kind == 'charge') scene.shake.trigger(_juice.shake['ultimate']!);
      case 'cancel':
        b.cancel(e.enemyId);
    }
  }
}

/// 원거리 적 탄 색(EnemyFired.kind): 깃털·가시·물·눈·불씨.
const _enemyShotColors = {
  'feather': 0xFFF4F1E8,
  'spike': 0xFFB36BFF,
  'water': 0xFF5DC8F0,
  'snow': 0xFFE6F6FF,
  'ember': 0xFFFF7A2F,
};
