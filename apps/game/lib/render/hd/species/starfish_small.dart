import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/starfish.dart';

/// 작은 불가사리(td_enemy:starfish_small — 불가사리가 쪼개져 생김): 같은 그리기, 둥글고 짧은 팔·금·가시 없음·동그란 눈·빨리 돎.
const starfishSmall = HdSpecies(_starfishSmall, extent: 1.35);

void _starfishSmall(HdKit k, Canvas c, double r, double t) => paintStarfish(k, c, r, t, small: true);
