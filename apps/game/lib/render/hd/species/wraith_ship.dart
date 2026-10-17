import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 망령선(순환): 반투명 민트 선체·민트 돛·유령 문양·금관 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const wraithShip = HdSpecies(_wraithShip, extent: 1.3, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFF9AE8CC),
  hullD: Color(0xFF3A9A80),
  sail: Color(0xFFD8FFF0),
  sailD: Color(0xFF78C8B0),
  flag: Color(0xFF3A9A80),
  emblem: ShipEmblem.ghost,
  sub: false,
  ghost: true,
  crown: true,
  ram: false,
  patch: false,
);

void _wraithShip(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
