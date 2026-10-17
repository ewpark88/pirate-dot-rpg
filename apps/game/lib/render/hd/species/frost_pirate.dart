import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 서리 해적선(순환): 얼음 파랑 선체·흰 돛·눈송이 문양·금관 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const frostPirate = HdSpecies(_frostPirate, extent: 1.5, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFF78B4E6),
  hullD: Color(0xFF2E6CA8),
  sail: Color(0xFFF4FCFF),
  sailD: Color(0xFFB8D8F0),
  flag: Color(0xFF8FD0F8),
  emblem: ShipEmblem.snowflake,
  sub: false,
  ghost: false,
  crown: true,
  ram: false,
);

void _frostPirate(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
