import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/seabird.dart';

/// 폭풍갈매기(td_enemy:stormgull — 폭풍 · 공중 · 원거리 깃털): 먹구름 회색 몸·번개 노랑 깃 끝, 꺾인 뾰족 날개·볏, 성난 눈.
const stormgull = HdSpecies(_stormgull, extent: 1.25, ground: 1.15, muzzle: Offset(-1.3, -0.15));

const SeabirdLook _look = (
  body: Color(0xFFB4BCC8),
  bodyD: Color(0xFF6E7888),
  wingTip: Color(0xFFFFE24A),
  wingTipD: Color(0xFFE0A000),
  angry: true,
  crest: true,
  bend: 1,
  round: 0,
);

void _stormgull(HdKit k, Canvas c, double r, double t) => drawSeabird(k, c, r, t, _look);
