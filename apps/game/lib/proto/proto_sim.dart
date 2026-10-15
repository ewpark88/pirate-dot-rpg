// 시뮬레이션은 필드를 한 줄씩 갱신하는 코드라 cascade(..)로 묶으면 오히려 읽기 어렵다.
// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:game_core/game_core.dart' show Rng, XorShiftRng;
import 'package:pirate_dot/proto/proto_entities.dart';

export 'package:pirate_dot/proto/proto_entities.dart';

part 'proto_weapons.dart';

/// 탑다운 전투 시험판(2026-10-15 사용자 결정 — 세로 유지 + 위에서 내려다보는 핵앤슬래시)의 시뮬레이션.
///
/// game_core와 별개인 단순 2D 시뮬. 좌표는 '논리 도트'(화면 폭 [viewWidth]도트), 시간은 초. 난수는 [Rng] 포트(결정론 —
/// 같은 시드면 같은 판). Flutter를 모른다(테스트·성능 측정이 쉽게).
///
/// - 배: 가운데 근처에서 원을 그리듯 자동 이동, 적이 몰린 쪽을 피한다. 세계는 위로 흘러간다(항해감).
/// - 적 3종(게·해파리·물고기)이 사방에서 무리로 몰려온다(최대 [maxEnemies]).
/// - 선원 계열 3개가 자동 공격: 투척(원형 폭발)·관통(직선 광선)·충격(원형 밀쳐내기).
/// - 3분 동안 점점 강해지는 파도(스폰 속도·체력·무리 습격), 배도 30초마다 강해진다.
class ProtoSim {
  ProtoSim({int seed = 1, this.viewWidth = 180, this.viewHeight = 320}) : rng = XorShiftRng(seed);

  final Rng rng;
  final double viewWidth;
  final double viewHeight;

  static const maxEnemies = 150;
  static const duration = 180.0;

  /// 경과 시간(초).
  double time = 0;
  bool get over => time >= duration;

  // 카메라(화면 가운데) — 일정한 속도로 위로 항해한다.
  double camX = 0;
  double camY = 0;
  static const sailSpeed = 14.0;

  final ship = ProtoShip();
  final enemies = <ProtoEnemy>[];
  final shots = <ProtoShot>[];
  final fx = <ProtoFx>[];
  final coins = <ProtoCoin>[];
  final numbers = <ProtoNumber>[];

  int kills = 0;
  int gold = 0;
  int hitsTaken = 0;

  double _spawnAcc = 0;
  double _nextSwarm = 25;
  double _lobCd = 0.5;
  double _pierceCd = 0.3;
  double _shockCd = 1;
  double _orbit = 0;

  /// 배 강화 단계(30초마다 +1) — 화력 ×(1 + 0.3 × 단계).
  int get powerLevel => (time / 30).floor();
  double get _power => 1 + 0.3 * powerLevel;

  /// 3분에 걸친 난이도 0→1.
  double get _heat => (time / duration).clamp(0.0, 1.0);

  /// 한 걸음(고정 [dt], 보통 1/60초).
  void step(double dt) {
    if (over) return;
    time += dt;
    camY -= sailSpeed * dt;
    _moveShip(dt);
    _spawn(dt);
    _moveEnemies(dt);
    _weapons(dt);
    _moveShots(dt);
    _moveCoins(dt);
    _age(dt);
  }

  // ───────── 배 ─────────

  void _moveShip(double dt) {
    // 기본: 화면 가운데를 중심으로 반지름 38도트 원(한 바퀴 약 14초).
    _orbit += dt * 0.45;
    final tx = camX + math.cos(_orbit) * 38;
    final ty = camY + 20 + math.sin(_orbit) * 26;
    var ax = (tx - ship.x) * 1.6;
    var ay = (ty - ship.y) * 1.6;
    // 적이 몰린 쪽을 피한다: 가까운 적에게서 밀려나는 힘(거리 제곱 반비례).
    for (final e in enemies) {
      final dx = ship.x - e.x;
      final dy = ship.y - e.y;
      final d2 = dx * dx + dy * dy;
      if (d2 < 48 * 48 && d2 > 1) {
        final f = 900 / d2;
        ax += dx / math.sqrt(d2) * f;
        ay += dy / math.sqrt(d2) * f;
      }
    }
    ship.vx = (ship.vx + ax * dt) * 0.9;
    ship.vy = (ship.vy + ay * dt) * 0.9;
    final sp = math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy);
    const maxSp = 46.0;
    if (sp > maxSp) {
      ship.vx *= maxSp / sp;
      ship.vy *= maxSp / sp;
    }
    ship.x += ship.vx * dt;
    ship.y += ship.vy * dt;
    // 화면 밖으로 나가지 않게
    final halfW = viewWidth / 2 - 10;
    final halfH = viewHeight / 2 - 16;
    ship.x = ship.x.clamp(camX - halfW, camX + halfW);
    ship.y = ship.y.clamp(camY - halfH, camY + halfH);
    final heading = math.atan2(ship.vy - sailSpeed, ship.vx);
    ship.angle = heading + math.pi / 2;
    if (ship.flash > 0) ship.flash -= dt;
  }

  // ───────── 적 ─────────

  void _spawn(double dt) {
    final rate = 2.0 + 11 * math.pow(_heat, 1.2); // 초당
    _spawnAcc += rate * dt;
    while (_spawnAcc >= 1 && enemies.length < maxEnemies) {
      _spawnAcc -= 1;
      _spawnOne(_pickKind(), angle: rng.nextDouble() * math.pi * 2);
    }
    if (_spawnAcc > 1) _spawnAcc = 1;
    if (time >= _nextSwarm) {
      // 무리 습격: 한 방향에서 한꺼번에(25~40마리)
      _nextSwarm += 25;
      final a = rng.nextDouble() * math.pi * 2;
      final n = 25 + (15 * _heat).round();
      for (var i = 0; i < n && enemies.length < maxEnemies; i++) {
        _spawnOne(_pickKind(), angle: a + (rng.nextDouble() - 0.5) * 0.7, spread: 22);
      }
    }
  }

  EnemyKind _pickKind() {
    final r = rng.nextDouble();
    // 처음엔 게·해파리 위주, 갈수록 빠른 물고기가 늘어난다.
    final fish = 0.15 + 0.35 * _heat;
    if (r < fish) return EnemyKind.fish;
    if (r < fish + 0.4) return EnemyKind.jelly;
    return EnemyKind.crab;
  }

  void _spawnOne(EnemyKind kind, {required double angle, double spread = 0}) {
    // 화면 가장자리 바로 바깥(가운데에서 각도 [angle] 방향으로 직사각형 경계까지).
    final cx = math.cos(angle);
    final cy = math.sin(angle);
    final hw = viewWidth / 2 + 12;
    final hh = viewHeight / 2 + 12;
    final t = math.min(hw / (cx.abs() + 1e-6), hh / (cy.abs() + 1e-6));
    final jitterX = (rng.nextDouble() - 0.5) * spread;
    final jitterY = (rng.nextDouble() - 0.5) * spread;
    final hpScale = 1 + 2.5 * _heat;
    enemies.add(
      ProtoEnemy(
        kind: kind,
        x: camX + cx * t + jitterX,
        y: camY + cy * t + jitterY,
        hp: kind.hp * hpScale,
        phase: rng.nextDouble() * math.pi * 2,
      ),
    );
  }

  void _moveEnemies(double dt) {
    for (final e in enemies) {
      var dx = ship.x - e.x;
      var dy = ship.y - e.y;
      final d = math.sqrt(dx * dx + dy * dy) + 1e-6;
      dx /= d;
      dy /= d;
      var sp = e.kind.speed;
      if (e.kind == EnemyKind.jelly) sp *= 0.7 + 0.5 * math.sin(time * 4 + e.phase).abs(); // 해파리: 꿀렁꿀렁
      e.vx = e.vx * 0.85 + dx * sp * 0.15;
      e.vy = e.vy * 0.85 + dy * sp * 0.15;
      e.x += (e.vx + e.kx) * dt;
      e.y += (e.vy + e.ky) * dt;
      e.kx *= 0.86; // 밀쳐내기 감쇠
      e.ky *= 0.86;
      if (e.flash > 0) e.flash -= dt;
      e.face = math.atan2(dy, dx);
      // 배에 닿으면: 배가 번쩍(피해 없음 — 시험판), 적은 튕겨 나감
      if (d < 9 + e.kind.radius) {
        e.kx -= dx * 60;
        e.ky -= dy * 60;
        if (ship.flash <= 0) {
          ship.flash = 0.25;
          hitsTaken++;
        }
      }
    }
    // 겹침 풀기(간단 격자 없이 — 150마리면 충분히 빠르다)
    final n = enemies.length;
    for (var i = 0; i < n; i++) {
      final a = enemies[i];
      for (var j = i + 1; j < n; j++) {
        final b = enemies[j];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final min = a.kind.radius + b.kind.radius;
        final d2 = dx * dx + dy * dy;
        if (d2 < min * min && d2 > 1e-4) {
          final d = math.sqrt(d2);
          final push = (min - d) * 0.5;
          final ux = dx / d;
          final uy = dy / d;
          a.x -= ux * push;
          a.y -= uy * push;
          b.x += ux * push;
          b.y += uy * push;
        }
      }
    }
  }

  void _moveCoins(double dt) {
    for (final c in coins) {
      c.age += dt;
      if (c.age < 0.35) {
        c.y -= 18 * dt; // 톡 튀어오름
        continue;
      }
      final dx = ship.x - c.x;
      final dy = ship.y - c.y;
      final d = math.sqrt(dx * dx + dy * dy) + 1e-6;
      final sp = 60 + c.age * 160;
      c.x += dx / d * sp * dt;
      c.y += dy / d * sp * dt;
      if (d < 6) {
        gold += c.value;
        c.taken = true;
      }
    }
    coins.removeWhere((c) => c.taken);
  }

  void _age(double dt) {
    for (final f in fx) {
      f.age += dt;
    }
    fx.removeWhere((f) => f.age >= f.life);
    for (final n in numbers) {
      n.age += dt;
      n.y -= 16 * dt;
    }
    numbers.removeWhere((n) => n.age >= n.life);
    // 너무 멀리 뒤처진 적은 지운다(배가 지나쳐 간 바다)
    enemies.removeWhere((e) => _d2(e.x, e.y, camX, camY) > 320 * 320);
  }

  static double _d2(double ax, double ay, double bx, double by) {
    final dx = ax - bx;
    final dy = ay - by;
    return dx * dx + dy * dy;
  }
}
