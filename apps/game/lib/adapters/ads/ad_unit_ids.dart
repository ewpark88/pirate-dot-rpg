/// 광고 ID. **Google 공식 테스트 ID만** 둔다 — 실제 ID 교체는 M5, 사람(`docs/store/admob.md`).
/// 테스트(`admob_ads_test.dart`)가 값을 고정해서 실수로 실제 ID가 들어오면 실패한다.
abstract final class AdUnitIds {
  static const androidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const iosRewarded = 'ca-app-pub-3940256099942544/1712485313';
}
