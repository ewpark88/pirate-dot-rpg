import 'package:flutter/painting.dart';
import 'package:game_data/game_data.dart';

/// 신화 테두리: 진한 빨강 + 금 안쪽 선 (사용자 지시 2026-10-16 '희귀(파랑)와 색이 비슷해 차이가 안 난다').
const mythicRed = Color(0xFFD7263D);
const mythicGold = Color(0xFFFFD447);

/// 등급 색 토큰 (UI 한 곳). `rarities.json`의 색("#9AA4B1") → Color (불투명). 신화는 표가 [mythicRed](S2 fa788e8).
Color rarityColor(RarityDef rarity) => Color(int.parse('FF${rarity.color.substring(1)}', radix: 16));

/// 신화면 금 안쪽 선을 그릴지 (테두리 위젯들이 쓴다).
bool rarityInnerGold(RarityDef rarity) => rarity.id == 'mythic';
