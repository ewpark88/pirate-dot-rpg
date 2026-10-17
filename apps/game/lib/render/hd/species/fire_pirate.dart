import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 화염 해적선(중간): 주황 갈색 선체·검은 돛·불꽃 문양 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const firePirate = HdSpecies(_firePirate, extent: 1.5, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFFD86A20),
  hullD: Color(0xFF8A3A00),
  sail: Color(0xFF4A3A40),
  sailD: Color(0xFF221A20),
  flag: Color(0xFFFF8A3A),
  emblem: ShipEmblem.flame,
  sub: false,
  ghost: false,
  crown: false,
  ram: false,
);

void _firePirate(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
