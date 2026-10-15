import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';

// 환생 v2 화면 문구 (id → ARB).

String shopName(AppLocalizations l, String id) => switch (id) {
  'startParts' => l.uiShopStartPartsName,
  'discount' => l.uiShopDiscountName,
  'bossTime' => l.uiShopBossTimeName,
  'offline' => l.uiShopOfflineName,
  'critChance' => l.uiShopCritChanceName,
  'critDamage' => l.uiShopCritDamageName,
  'fleetSlot' => l.uiShopFleetSlotName,
  'pieceGain' => l.uiShopPieceGainName,
  _ => l.uiShopFastSailName,
};

String shopDesc(AppLocalizations l, String id) => switch (id) {
  'startParts' => l.uiShopStartPartsDesc,
  'discount' => l.uiShopDiscountDesc,
  'bossTime' => l.uiShopBossTimeDesc,
  'offline' => l.uiShopOfflineDesc,
  'critChance' => l.uiShopCritChanceDesc,
  'critDamage' => l.uiShopCritDamageDesc,
  'fleetSlot' => l.uiShopFleetSlotDesc,
  'pieceGain' => l.uiShopPieceGainDesc,
  _ => l.uiShopFastSailDesc,
};

/// 효과 숫자 → 짧은 글 ('+15레벨', '−20%', '+0.3').
String shopFx(AppLocalizations l, ShopFx fx, double value) {
  final n = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
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
  'coral' => l.uiSkinCoral,
  'storm' => l.uiSkinStorm,
  'gold' => l.uiSkinGold,
  _ => l.uiSkinPhantom,
};

String titleName(AppLocalizations l, String id) => switch (id) {
  'deckhand' => l.uiTitleDeckhand,
  'navigator' => l.uiTitleNavigator,
  'captain' => l.uiTitleCaptain,
  'admiral' => l.uiTitleAdmiral,
  _ => l.uiTitleSeaKing,
};

/// 미리보기 한 줄 (스펙 3-2: 소수 1자리, 1.1 미만은 '×1.1 미만', 60분 넘으면 '1시간+').
String forecastText(AppLocalizations l, ForecastVm f) {
  final mult = f.powerMultiplier.toStringAsFixed(1);
  if (f.minutesToBeat > 60) return l.uiRebirthForecastLong(mult, f.targetStage);
  if (f.powerMultiplier < 1.1) return l.uiRebirthForecastSmall(f.minutesToBeat, f.targetStage);
  return l.uiRebirthForecast(f.minutesToBeat, mult, f.targetStage);
}
