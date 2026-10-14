import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pirate_dot/adapters/ads/ad_unit_ids.dart';
import 'package:pirate_dot/adapters/ads/ads_sdk.dart';

/// 실제 AdMob·UMP. iOS는 ATT 전(M6)이라 동의 단계에서 false — 광고 없음.
class GoogleAdsSdk implements AdsSdk {
  RewardedAd? _ad;
  bool _privacyRequired = false;

  @override
  Future<bool> gatherConsent() async {
    if (!Platform.isAndroid) return false;
    final info = ConsentInformation.instance;
    final updated = Completer<void>();
    info.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      updated.complete,
      (e) => updated.completeError(StateError('UMP: ${e.message}')),
    );
    try {
      await updated.future;
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    } on Object {
      // 갱신 실패여도 지난 세션의 동의가 남아 있으면 광고를 요청할 수 있다.
    }
    _privacyRequired = await info.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
    return info.canRequestAds();
  }

  @override
  Future<void> initialize() => MobileAds.instance.initialize();

  @override
  Future<bool> load() {
    final done = Completer<bool>();
    unawaited(
      RewardedAd.load(
        adUnitId: Platform.isAndroid ? AdUnitIds.androidRewarded : AdUnitIds.iosRewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            done.complete(true);
          },
          onAdFailedToLoad: (_) => done.complete(false),
        ),
      ),
    );
    return done.future;
  }

  @override
  Future<AdShowOutcome> show() async {
    final ad = _ad;
    _ad = null;
    if (ad == null) return AdShowOutcome.failed;
    final done = Completer<AdShowOutcome>();
    var rewarded = false;
    void finish(AdShowOutcome o) {
      if (!done.isCompleted) done.complete(o);
      unawaited(ad.dispose());
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(rewarded ? AdShowOutcome.rewarded : AdShowOutcome.dismissed),
      onAdFailedToShowFullScreenContent: (_, _) => finish(AdShowOutcome.failed),
    );
    await ad.show(onUserEarnedReward: (_, _) => rewarded = true);
    return done.future;
  }

  @override
  bool get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((_) {});
}
