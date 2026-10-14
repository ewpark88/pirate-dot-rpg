/// 광고 SDK 표시 결과. 보상 콜백이 왔으면 [rewarded] (닫힘보다 우선).
enum AdShowOutcome { rewarded, dismissed, failed }

/// AdMob·UMP를 감싼 얇은 경계. 실제 구현은 `google_ads_sdk.dart`, 테스트는 가짜.
abstract interface class AdsSdk {
  /// UMP 동의 정보 갱신 → 필요하면 폼 → 광고 요청 가능 여부(`canRequestAds`).
  Future<bool> gatherConsent();

  /// `MobileAds.instance.initialize()`. 동의 뒤에 한 번.
  Future<void> initialize();

  /// 보상형 광고 1개 로드. 성공하면 true.
  Future<bool> load();

  /// 로드된 광고를 보여 주고 닫힐 때 끝난다. 로드된 광고는 소비된다.
  Future<AdShowOutcome> show();

  /// 설정의 "개인정보 옵션" 버튼을 보일지 (UMP privacy options).
  bool get privacyOptionsRequired;

  Future<void> showPrivacyOptions();
}
