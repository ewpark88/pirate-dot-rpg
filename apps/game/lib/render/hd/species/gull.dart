import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/seabird.dart';

/// 갈매기(td_enemy:gull — 산호 · 공중 · 원거리 깃털): 흰 몸·회색 깃 끝·둥근 날개, 장난스러운 큰 눈.
const gull = HdSpecies(_gull, extent: 1.5, ground: 1.15);

const SeabirdLook _look = (
  body: Color(0xFFFFFFFF),
  bodyD: Color(0xFFC3CEDE),
  wingTip: Color(0xFF8A96AA),
  wingTipD: Color(0xFF55607A),
  angry: false,
  crest: false,
  bend: 0,
  round: 0.2,
);

void _gull(HdKit k, Canvas c, double r, double t) => drawSeabird(k, c, r, t, _look);
