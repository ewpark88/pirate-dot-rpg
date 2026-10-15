import 'dart:math' as math;

/// 시험판의 배·적·탄·연출·금화·숫자 (시뮬(ProtoSim)이 갱신하고 화면이 그린다).
enum EnemyKind {
  crab(hp: 7, speed: 15, radius: 5, gold: 2),
  jelly(hp: 4, speed: 22, radius: 4, gold: 1),
  fish(hp: 2.5, speed: 36, radius: 4, gold: 1);

  const EnemyKind({required this.hp, required this.speed, required this.radius, required this.gold});

  final double hp;
  final double speed;
  final double radius;
  final int gold;
}

class ProtoShip {
  double x = 0;
  double y = 20;
  double vx = 0;
  double vy = 0;
  double angle = 0;
  double flash = 0;
}

class ProtoEnemy {
  ProtoEnemy({required this.kind, required this.x, required this.y, required this.hp, required this.phase});

  final EnemyKind kind;
  double x;
  double y;
  double hp;
  final double phase;
  double vx = 0;
  double vy = 0;
  double kx = 0;
  double ky = 0;
  double flash = 0;
  double face = 0;
}

class ProtoShot {
  ProtoShot.lob(this.sx, this.sy, this.tx, this.ty);

  final double sx;
  final double sy;
  final double tx;
  final double ty;
  final double flight = 0.45;
  double t = 0;
  bool done = false;

  /// 포물선 위치(0~1 진행).
  (double, double) pos() {
    final u = (t / flight).clamp(0.0, 1.0);
    final arc = math.sin(u * math.pi) * 22;
    return (sx + (tx - sx) * u, sy + (ty - sy) * u - arc);
  }
}

enum FxKind { blast, beam, ring, pop }

class ProtoFx {
  ProtoFx(this.kind, this.x, this.y, {required this.life, this.angle = 0, this.size = 0});

  final FxKind kind;
  final double x;
  final double y;
  final double life;
  final double angle;
  final double size;
  double age = 0;

  double get u => (age / life).clamp(0.0, 1.0);
}

class ProtoCoin {
  ProtoCoin(this.x, this.y, {required this.value});

  double x;
  double y;
  final int value;
  double age = 0;
  bool taken = false;
}

class ProtoNumber {
  ProtoNumber(this.x, this.y, this.value, {required this.life});

  final double x;
  double y;
  final int value;
  final double life;
  double age = 0;
}
