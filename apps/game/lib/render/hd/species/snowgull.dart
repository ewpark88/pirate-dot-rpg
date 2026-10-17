import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/seabird.dart';

/// 눈갈매기(td_enemy:snowgull — 빙하 · 공중 · 원거리 깃털): 둥글고 털 많은 흰 몸·하늘색 깃 끝, 둥근 날개, 볼 홍조.
const snowgull = HdSpecies(_snowgull, extent: 1.5, ground: 1.15);

const SeabirdLook _look = (
  body: Color(0xFFFFFFFF),
  bodyD: Color(0xFFCFE4F4),
  wingTip: Color(0xFF8FD0F8),
  wingTipD: Color(0xFF4A9AD8),
  angry: false,
  crest: false,
  bend: 0,
  round: 1,
);

void _snowgull(HdKit k, Canvas c, double r, double t) => drawSeabird(k, c, r, t, _look);
