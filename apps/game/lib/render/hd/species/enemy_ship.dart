import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 해적선(모든 해역 기본 보스): 갈색 선체·크림 돛·해골 문양 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const enemyShip = HdSpecies(_enemyShip, extent: 1.3, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFF8A5030),
  hullD: Color(0xFF4A2C2A),
  sail: Color(0xFFFFF4DC),
  sailD: Color(0xFFD8C8A0),
  flag: Color(0xFF2A2430),
  emblem: ShipEmblem.skull,
  sub: false,
  ghost: false,
  crown: false,
  ram: false,
  patch: false,
);

void _enemyShip(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
