// 시뮬레이션 갱신 코드라 cascade로 묶지 않는다(proto_sim.dart와 같음).
// ignore_for_file: cascade_invocations

part of 'proto_sim.dart';

/// 선원 계열 3개의 자동 공격: 투척(원형 폭발)·관통(직선 광선)·충격(원형 밀쳐내기), 피해·처치 정리.
extension _Weapons on ProtoSim {
  void _weapons(double dt) {
    _lobCd -= dt;
    _pierceCd -= dt;
    _shockCd -= dt;
    if (enemies.isEmpty) return;
    if (_lobCd <= 0) {
      _lobCd = 1.1;
      final target = _densest();
      if (target != null) {
        shots.add(ProtoShot.lob(ship.x, ship.y, target.x, target.y));
      }
    }
    if (_pierceCd <= 0) {
      _pierceCd = 0.7;
      final t = _nearest();
      if (t != null) _pierce(math.atan2(t.y - ship.y, t.x - ship.x));
    }
    if (_shockCd <= 0) {
      _shockCd = 2.2;
      _shock();
    }
  }

  ProtoEnemy? _nearest() {
    ProtoEnemy? best;
    var bd = double.infinity;
    for (final e in enemies) {
      final d = ProtoSim._d2(e.x, e.y, ship.x, ship.y);
      if (d < bd) (best, bd) = (e, d);
    }
    return best;
  }

  /// 반지름 18 안 이웃이 가장 많은 적(최대 40마리만 표본 — 결정론 순서).
  ProtoEnemy? _densest() {
    ProtoEnemy? best;
    var most = -1;
    final step = math.max(1, enemies.length ~/ 40);
    for (var i = 0; i < enemies.length; i += step) {
      final a = enemies[i];
      if (ProtoSim._d2(a.x, a.y, ship.x, ship.y) > 110 * 110) continue;
      var n = 0;
      for (final b in enemies) {
        if (ProtoSim._d2(a.x, a.y, b.x, b.y) < 18 * 18) n++;
      }
      if (n > most) (best, most) = (a, n);
    }
    return best;
  }

  void _pierce(double angle) {
    const length = 150.0;
    const width = 5.0;
    final ux = math.cos(angle);
    final uy = math.sin(angle);
    fx.add(ProtoFx(FxKind.beam, ship.x, ship.y, life: 0.16, angle: angle, size: length));
    for (final e in enemies) {
      final rx = e.x - ship.x;
      final ry = e.y - ship.y;
      final along = rx * ux + ry * uy;
      if (along < 0 || along > length) continue;
      final across = (rx * -uy + ry * ux).abs();
      if (across < width + e.kind.radius) _hit(e, 4 * _power);
    }
  }

  void _shock() {
    const radius = 34.0;
    fx.add(ProtoFx(FxKind.ring, ship.x, ship.y, life: 0.3, size: radius));
    for (final e in enemies) {
      final dx = e.x - ship.x;
      final dy = e.y - ship.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < radius + e.kind.radius) {
        _hit(e, 3 * _power);
        final k = 70 / (d + 1);
        e.kx += dx * k;
        e.ky += dy * k;
      }
    }
  }

  void _moveShots(double dt) {
    for (final s in shots) {
      s.t += dt;
      if (s.t >= s.flight && !s.done) {
        s.done = true;
        const radius = 20.0;
        fx.add(ProtoFx(FxKind.blast, s.tx, s.ty, life: 0.35, size: radius));
        var total = 0.0;
        for (final e in enemies) {
          if (ProtoSim._d2(e.x, e.y, s.tx, s.ty) < (radius + e.kind.radius) * (radius + e.kind.radius)) {
            _hit(e, 6 * _power);
            total += 6 * _power;
          }
        }
        // 숫자는 폭발마다 합계 하나(적마다 띄우면 화면이 숫자로 덮인다 — 본 게임의 범위 합계와 같은 규칙)
        if (total > 0 && numbers.length < 24) numbers.add(ProtoNumber(s.tx, s.ty - 10, total.round(), life: 0.7));
      }
    }
    shots.removeWhere((s) => s.done);
    _reap();
  }

  void _hit(ProtoEnemy e, double dmg) {
    if (e.hp <= 0) return;
    e.hp -= dmg;
    e.flash = 0.08;
  }

  void _reap() {
    enemies.removeWhere((e) {
      if (e.hp > 0) return false;
      kills++;
      fx.add(ProtoFx(FxKind.pop, e.x, e.y, life: 0.25, size: e.kind.radius + 3));
      coins.add(ProtoCoin(e.x, e.y, value: e.kind.gold));
      return true;
    });
    _reapShock();
  }

  void _reapShock() {
    // 충격·관통은 즉시 피해라 여기서도 정리
  }
}
