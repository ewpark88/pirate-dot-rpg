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
    final color =
        scene.topHits.skinMuzzle ?? parseArgb(colors[rarity.clamp(0, colors.length - 1)].color, 'rarities.color');
    final delayMs = math.max<double>(0, (start - _player.position) * _player.tickMs / math.max(1, frame.speed));
    // 추적 깃털: 방금 띄운 이 선원 발사체를 옆으로 휘게(좌우 번갈아).
    final curve = scene.topHits.traits?.curveFor(e.crewId, rarity, e.tick) ?? 0;
    for (final p in scene.projectiles.active) {
      if (p.crewId == e.crewId && p.progress == 0) p.curve = curve;
    }
    scene.topHits.muzzles.muzzle(
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
    scene.topHits.muzzle.firedBosses(scene.clockMs); // 쏘기 직전 빛 → 터짐
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
    scene.topHits.muzzle.fired(e.enemyId, scene.clockMs); // HD 쏘는 부위 번쩍
    scene.sound.sfx('enemyFired', clockMs: scene.clockMs, tick: e.tick);
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
    scene.topHits.emerges.add(e.x, e.y, scene.clockMs, e.warnTicks * _player.tickMs / math.max(1, frame.speed));
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
      scene.topHits.slash.swing(
        ship.dx,
        ship.dy,
        t?.x ?? e.x,
        t?.y ?? e.y,
        scene.clockMs + delayMs,
        color,
        rarity: rarity,
      );
    }
    if (rarity >= 4) scene.shake.trigger(_juice.shake['aoe']!); // 신화 회전 베기: 화면 미세 흔들림
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

  /// 범위 피해 합: 합계 숫자 + 흔들림, 탑다운은 임팩트 v2(반경 = 이번 틱 같은 선원이 맞힌 적 중 가장 먼 거리 + 6).
  void _aoe(AoeDamageSum e, RecordedTick tick, int index) {
    scene.numbers.add(e.total, e.x, e.y - kNumberLiftPx * 2, DamageKind.sum);
    scene.shake.trigger(_juice.shake['aoe']!);
    if (!scene.isTop) return;
    String? crew;
    var r = 12.0;
    for (final d in tick.events.whereType<Damage>()) {
      final en = _player.enemyAt(index, d.targetId) ?? _player.enemyAt(index - 1, d.targetId);
      if (en == null) continue;
      final dist = math.sqrt((en.x - e.x) * (en.x - e.x) + (en.y - e.y) * (en.y - e.y));
      if (dist > 70 || (crew != null && d.crewId != crew)) continue;
      crew ??= d.crewId;
      r = math.max(r, dist + 6);
    }
    var rarity = 0;
    for (final s in tick.frame.fleet) {
      if (s.crewId == crew) rarity = s.rarity;
    }
    final colors = scene.tables.rarities.rarities;
    final color = parseArgb(colors[rarity.clamp(0, colors.length - 1)].color, 'rarities.color');
    final water = crew != null && _crewFamily[crew] == 'underwater';
    scene.topHits.impact.add(e.x, e.y, math.min(r, 64), color, scene.clockMs, water: water);
    // 타격감 v3: 범위 = 중 단계(히트스톱·방향 흔들림), 맞은 적은 폭심에서 바깥으로 튕김.
    scene.topHits.juice.hit(
      scene.clockMs,
      Offset(e.x, e.y) - scene.topShip,
      strong: false,
      shake: scene.settings.shake,
    );
    for (final d in tick.events.whereType<Damage>()) {
      final en = _player.enemyAt(index, d.targetId);
      if (en != null) scene.topHits.juice.knock(d.targetId, Offset(en.x, en.y), Offset(e.x, e.y), scene.clockMs);
    }
    scene.sound.thud(scene.clockMs, big: false);
  }

  /// 발사체 비행 구간(틱): 엔진이 flightTicks(개성 v2 조준탄)를 주면 쏜 틱부터 그만큼 날아 닿는다(빗나가면 AttackMissed),
  /// 없으면 옛 방식 — fx_map 비행 시간만큼 앞서 띄워 엔진 피해 시각(index)에 닿는다.
  (double, double) _flightWindow(AttackFired e, int index, double tickMs) {
    final f = e.flightTicks;
    if (f != null) return (index.toDouble(), (index + f).toDouble());
    final flightTicks = math.min(_rules.flightMs(e.family) / tickMs, _juice.lookaheadTicks.toDouble());
    return (index - flightTicks, index.toDouble());
  }

  /// 낙뢰(개성 v2 pelly, AttackFired.kind 'lightning'): 쏜 틱부터 flightTicks 동안 예고, 그 뒤 내리꽂힘(TopCrewFx).
  void _lightning(AttackFired e, int index, BattleView frame) {
    final speed = math.max(1, frame.speed);
    final delayMs = math.max<double>(0, (index - _player.position) * _player.tickMs / speed);
    final warnMs = (e.flightTicks ?? 8) * _player.tickMs / speed;
    scene.topHits.crew.lightning(e.x, e.y, scene.clockMs + delayMs, warnMs);
    _flashSlot(frame, e.crewId);
  }

  /// 배 피격: 번쩍(탑다운은 300ms마다 한 번)·체력·숫자(막이 다 받아 0이면 숫자 대신 막 물결)·돌진·물보라·침몰.
  static const int _shipNumberKey = 1 << 30;

  void _shipHit(ShipDamaged e, RecordedTick tick) {
    if (!scene.isTop) {
      scene.shipFlashMs = _juice.flashFrames * kFrameMs;
    } else if (scene.topHits.takeFlash(scene.clockMs)) {
      scene.shipFlashMs = _kTopHitFlashMs;
    }
    scene.shipHpRatio = e.hpRatio;
    // 0으로 보이는 작은 피해(1 미만)는 숫자 없이 물결만, 배 피해는 한 숫자로 합친다(따로 쌓여 '0'이 세로로 늘어서던 것 — S5 실기기).
    if (e.amount.isZero || e.amount.format() == '0') {
      scene.topHits.crew.rippleAt = scene.clockMs;
    } else {
      scene.numbers.add(e.amount, _shipNumberAt(e).dx, _shipNumberAt(e).dy, DamageKind.ship, key: _shipNumberKey);
    }
    if (scene.isTop && e.fromX != null && e.fromY != null) scene.topHits.hit(scene, e.fromX!, e.fromY!);
    // 돌격대 박치기: 큰 충돌(강 단계 흔들림·멈춤 + 붉은 폭발).
    if (scene.isTop && e.fromX != null && _vanguardAt(e.fromX!, e.fromY!)) {
      scene.topHits.juice.hit(
        scene.clockMs,
        Offset(e.fromX!, e.fromY!) - scene.topShip,
        strong: true,
        shake: scene.settings.shake,
      );
      scene.topHits.impact.add(e.fromX!, e.fromY!, 26, 0xFFE8443A, scene.clockMs);
    }
    if (e.hpRatio <= 0 && !tick.frame.bossActive) scene.moments.onShipSunk();
  }

  /// 타격감 v3 명중: 약 = 흰 번쩍(기존) · 중(치명) = 히트스톱 40ms·흔들림 2dp·넉백 · 강(보스) = 60ms·4dp + 낮은 '쿵'.
  void _juiceHit(Damage e, int index) {
    final en = _player.enemyAt(index, e.targetId);
    if (en == null) return;
    if (!scene.topHits.lite) scene.topHits.juice.squash(e.targetId, scene.clockMs); // 손맛 v4 찌그러짐
    if (e.crit) scene.topHits.juice.critStar(en.x, en.y, scene.clockMs);
    // 레이저가 켜진 선원의 피해: 맞은 자리 작은 불꽃.
    final crew = e.crewId;
    if (crew != null && scene.topHits.family.beaming(crew, scene.clockMs)) {
      scene.topHits.impact.add(en.x, en.y, 8, 0xFFFFE08A, scene.clockMs);
    }
    final strong = en.boss;
    if (!strong && !e.crit) return;
    final ship = scene.topShip;
    final at = Offset(en.x, en.y);
    scene.topHits.juice
      ..hit(scene.clockMs, at - ship, strong: strong, shake: scene.settings.shake)
      ..knock(e.targetId, at, ship, scene.clockMs, units: strong ? 3 : 5);
    scene.sound.thud(scene.clockMs, big: strong);
  }

  /// 타격감 v3 처치: 잉크·조각이 튐(적 크기 8) + 한꺼번에 많이 잡으면 연쇄 폭발(피드백 #4).
  void _juiceKill(Kill e) {
    scene.topHits.juice.pop(e.x, e.y, scene.clockMs, 8);
    scene.topHits.impact.chainKill(e.x, e.y, scene.clockMs);
  }

  /// 탑다운 보스 처치(피드백 #18): 흔들림·슬로모션·가장자리 빛 + 보스 자리에서 보상 터짐(연쇄 폭발 → 금화·젬 → 배로).
  void _topBossKill(Kill e) {
    if (scene.slowMoMs > 0) return;
    scene.shake.trigger(_juice.shake['bossKill']!);
    scene
      ..haptic(HapticLevel.medium)
      ..slowMoMs = _juice.bossSlowMoMs;
    if (_juice.bossFlash && scene.settings.flash) scene.screenFlashMs = _juice.flashFrames * kFrameMs * 2;
    scene.topHits.loot.burst(scene.clockMs, Offset(e.x, e.y), lite: scene.topHits.lite || scene.settings.powerSave);
    scene.numbers.add(e.gold, e.x, e.y - 18, DamageKind.crit);
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
