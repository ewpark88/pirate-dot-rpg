import 'package:flutter/painting.dart';
import 'package:game_data/game_data.dart';

/// `rarities.json`의 색("#9AA4B1") → Color (불투명).
Color rarityColor(RarityDef rarity) => Color(int.parse('FF${rarity.color.substring(1)}', radix: 16));
