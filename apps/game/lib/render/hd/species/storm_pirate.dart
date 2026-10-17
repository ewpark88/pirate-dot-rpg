import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 폭풍 해적선(중간): 녹슨 갈색 선체·회색 돛·번개 문양 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const stormPirate = HdSpecies(_stormPirate, extent: 1.5, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFFB05A44),
  hullD: Color(0xFF6A2A1E),
  sail: Color(0xFFB4BCC8),
  sailD: Color(0xFF6E7888),
  flag: Color(0xFFFFE24A),
  emblem: ShipEmblem.lightning,
  sub: false,
  ghost: false,
  crown: false,
  ram: false,
);

void _stormPirate(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
