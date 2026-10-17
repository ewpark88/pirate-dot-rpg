import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 유령선(중간): 반투명 회색 선체·옅은 돛·유령 문양 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const ghostShip = HdSpecies(_ghostShip, extent: 1.3, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFFB8C4C6),
  hullD: Color(0xFF5A6668),
  sail: Color(0xFFF0F4F4),
  sailD: Color(0xFFA8B4B6),
  flag: Color(0xFF5A6668),
  emblem: ShipEmblem.ghost,
  sub: false,
  ghost: true,
  crown: false,
  ram: false,
  patch: true,
);

void _ghostShip(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
