import 'package:game_core/contracts.dart';

/// 광고 없음. UI provider의 기본값, SDK가 없거나 실패했을 때.
class NoAds implements AdsPort {
  const NoAds();

  @override
  bool isReady(AdPlacement placement) => false;

  @override
  Future<AdResult> show(AdPlacement placement) async => AdResult.notLoaded;
}
