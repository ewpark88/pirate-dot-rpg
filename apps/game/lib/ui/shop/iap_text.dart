import 'package:pirate_dot/l10n/gen/app_localizations.dart';

/// 유료 상품 이름(iap.json nameKey → 경제 ARB econIap*). 표에 상품이 늘면 여기 한 줄(shop_test가 빠진 키를 잡는다).
String iapName(AppLocalizations l, String key) => _names[key]?.call(l) ?? key;

/// 이름이 있는 키(시험용).
bool hasIapName(String key) => _names.containsKey(key);

final Map<String, String Function(AppLocalizations)> _names = {
  'econIapNoAds30d': (l) => l.econIapNoAds30d,
  'econIapNoAds': (l) => l.econIapNoAds,
  'econIapSpeed30d': (l) => l.econIapSpeed30d,
  'econIapSpeed': (l) => l.econIapSpeed,
  'econIapCaptainPack': (l) => l.econIapCaptainPack,
  'econIapStarterPack': (l) => l.econIapStarterPack,
  'econIapGem120': (l) => l.econIapGem120,
  'econIapGem650': (l) => l.econIapGem650,
  'econIapGem1400': (l) => l.econIapGem1400,
  'econIapGem4200': (l) => l.econIapGem4200,
  'econIapGem9000': (l) => l.econIapGem9000,
  'econIapGemMonthly': (l) => l.econIapGemMonthly,
  'econIapVoyagePass': (l) => l.econIapVoyagePass,
  'econIapSkinGoldenGalleon': (l) => l.econIapSkinGoldenGalleon,
  'econIapSkinJollyFlag': (l) => l.econIapSkinJollyFlag,
  'econIapSkinCoralYacht': (l) => l.econIapSkinCoralYacht,
  'econIapSkinBundle': (l) => l.econIapSkinBundle,
  'econIapOffline12h': (l) => l.econIapOffline12h,
};
