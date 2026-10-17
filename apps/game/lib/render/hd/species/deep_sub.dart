import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 심해 잠수함(중간): 노란 통 선체·둥근 함교·잠망경·닻 문양 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const deepSub = HdSpecies(_deepSub, extent: 1.5, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFFF2CC3A),
  hullD: Color(0xFFA87A08),
  sail: Color(0xFFF2CC3A),
  sailD: Color(0xFFA87A08),
  flag: Color(0xFF2A2430),
  emblem: ShipEmblem.anchor,
  sub: true,
  ghost: false,
  crown: false,
  ram: false,
);

void _deepSub(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
