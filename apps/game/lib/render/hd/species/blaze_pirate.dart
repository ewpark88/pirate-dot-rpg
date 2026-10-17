import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 불꽃 해적선(순환): 검붉은 선체·주황 돛·불꽃 문양·금관 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const blazePirate = HdSpecies(_blazePirate, extent: 1.3, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFF8A3020),
  hullD: Color(0xFF4A120C),
  sail: Color(0xFFFF8A3A),
  sailD: Color(0xFFC8401A),
  flag: Color(0xFFFFC23A),
  emblem: ShipEmblem.flame,
  sub: false,
  ghost: false,
  crown: true,
  ram: false,
  patch: false,
);

void _blazePirate(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
