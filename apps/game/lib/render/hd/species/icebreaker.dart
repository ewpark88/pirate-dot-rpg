import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_ship.dart';

/// 쇄빙선(중간): 하늘색 선체·흰 돛·눈송이 문양·뱃머리 충각 — 배 보스 공용 몸(boss_ship.dart), 정면 3/4.
const icebreaker = HdSpecies(_icebreaker, extent: 1.5, ground: 0.95);

const ShipLook _look = (
  hull: Color(0xFF8ACCF2),
  hullD: Color(0xFF3A8AC8),
  sail: Color(0xFFFFFFFF),
  sailD: Color(0xFFC8DCEC),
  flag: Color(0xFF8FD0F8),
  emblem: ShipEmblem.snowflake,
  sub: false,
  ghost: false,
  crown: false,
  ram: true,
);

void _icebreaker(HdKit k, Canvas c, double r, double t) => drawShipBoss(k, c, r, t, _look);
