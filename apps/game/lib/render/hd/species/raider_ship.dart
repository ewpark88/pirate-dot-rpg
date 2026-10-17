import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 약탈선(중간): 짙은 빨강 선체·베이지 돛·해골 문양 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const raiderShip = HdSpecies(_raiderShip, extent: 1.5, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFFA83A2C),
  hullD: Color(0xFF5A1610),
  sail: Color(0xFFF0E0C0),
  sailD: Color(0xFFC8B088),
  flag: Color(0xFF2A2430),
  emblem: ShipEmblem.skull,
  sub: false,
  ghost: false,
  crown: false,
  ram: false,
);

void _raiderShip(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
