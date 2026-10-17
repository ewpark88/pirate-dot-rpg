import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 폭풍 약탈선(순환): 먹구름 남색 선체·짙은 회색 돛·번개 문양·금관 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const stormRaider = HdSpecies(_stormRaider, extent: 1.5, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFF5A6290),
  hullD: Color(0xFF2C3150),
  sail: Color(0xFF8A93A8),
  sailD: Color(0xFF4E5668),
  flag: Color(0xFFFFE24A),
  emblem: ShipEmblem.lightning,
  sub: false,
  ghost: false,
  crown: true,
  ram: false,
);

void _stormRaider(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
