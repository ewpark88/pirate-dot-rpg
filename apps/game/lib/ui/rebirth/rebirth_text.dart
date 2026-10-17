import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';

// 환생 v2 화면 문구 (id → ARB). 이름·설명은 경제 테이블 키(econRebirthShop*·econTitle*·shipSkin*).

String shopName(AppLocalizations l, String id) => switch (id) {
  'startParts' => l.econRebirthShopStartPartsName,
  'discount' => l.econRebirthShopDiscountName,
  'bossTime' => l.econRebirthShopBossTimeName,
  'offline' => l.econRebirthShopOfflineName,
  'critChance' => l.econRebirthShopCritChanceName,
  'critDamage' => l.econRebirthShopCritDamageName,
  'fleetSlot' => l.econRebirthShopFleetSlotName,
  'pieceGain' => l.econRebirthShopPieceGainName,
  _ => l.econRebirthShopFastSailName,
};

String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// 설명 한 줄 — 다음 레벨 값으로 채운다(최대 레벨이면 지금 값).
String shopDesc(AppLocalizations l, ShopItemVm it) {
  final v = it.effectNext ?? it.effectNow;
  final shown = _n(shopDisplay(it.id, v).$2);
  return switch (it.id) {
    'startParts' => l.econRebirthShopStartPartsDesc(_n(it.minorNext ?? it.minorNow ?? 0), shown),
    'discount' => l.econRebirthShopDiscountDesc(shown),
    'bossTime' => l.econRebirthShopBossTimeDesc(shown),
    'offline' => l.econRebirthShopOfflineDesc(shown),
    'critChance' => l.econRebirthShopCritChanceDesc(shown),
    'critDamage' => l.econRebirthShopCritDamageDesc(shown),
    'fleetSlot' => l.econRebirthShopFleetSlotDesc(shown),
    'pieceGain' => l.econRebirthShopPieceGainDesc(shown),
    _ => l.econRebirthShopFastSailDesc(shown),
  };
}

/// 상점 [id]의 경제 값 → 짧은 글 ('+15레벨', '-20%', '+0.3').
String shopFx(AppLocalizations l, String id, double value) {
  final (fx, v) = shopDisplay(id, value);
  final n = _n(v);
  return switch (fx) {
    ShopFx.levels => l.uiShopFxLevels(n),
    ShopFx.down => l.uiShopFxDown(n),
    ShopFx.sec => l.uiShopFxSec(n),
    ShopFx.hour => l.uiShopFxHour(n),
    ShopFx.pp => l.uiShopFxPp(n),
    ShopFx.plus => l.uiShopFxPlus(n),
    ShopFx.slots => l.uiShopFxSlots(n),
    ShopFx.percent => l.uiShopFxPercent(n),
  };
}

String skinName(AppLocalizations l, String id) => switch (id) {
  'coral' => l.shipSkinCoral,
  'storm' => l.shipSkinStorm,
  'gold' => l.shipSkinGold,
  _ => l.shipSkinPhantom,
};

String titleName(AppLocalizations l, String id) => switch (id) {
  'deckhand' => l.econTitleDeckhand,
  'navigator' => l.econTitleNavigator,
  'captain' => l.econTitleCaptain,
  'admiral' => l.econTitleAdmiral,
  'passFlag' => l.uiTitlePassFlag, // 항해 패스 시즌1 30단계 무료
  _ => l.econTitleSeaKing,
};

/// 미리보기 한 줄 (스펙 3-2: 소수 1자리, 1.1 미만은 '×1.1 미만', 60분 넘으면 '1시간+').
String forecastText(AppLocalizations l, ForecastVm f) {
  final mult = f.powerMultiplier.toStringAsFixed(1);
  if (f.minutesToBeat > 60) return l.uiRebirthForecastLong(mult, f.targetStage);
  if (f.powerMultiplier < 1.1) return l.uiRebirthForecastSmall(f.minutesToBeat, f.targetStage);
  return l.uiRebirthForecast(f.minutesToBeat, mult, f.targetStage);
}
