import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/lavacrab.dart';

/// 작은 용암게(td_enemy:lavacrab_small — 용암게가 쪼개져 생김): 같은 그리기, 금 없는 매끈한 등딱지·작은 집게·놀란 눈·종종걸음.
const lavacrabSmall = HdSpecies(_lavacrabSmall, extent: 1.35, ground: 0.72);

void _lavacrabSmall(HdKit k, Canvas c, double r, double t) => paintLavacrab(k, c, r, t, small: true);
