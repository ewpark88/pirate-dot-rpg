import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 사냥 잠수함(순환): 빨간 통 선체·둥근 함교·잠망경·해골 문양·금관 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const hunterSub = HdSpecies(_hunterSub, extent: 1.3, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFFE04848),
  hullD: Color(0xFF8A1A1A),
  sail: Color(0xFFE04848),
  sailD: Color(0xFF8A1A1A),
  flag: Color(0xFF2A2430),
  emblem: ShipEmblem.skull,
  sub: true,
  ghost: false,
  crown: true,
  ram: false,
  patch: false,
);

void _hunterSub(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
