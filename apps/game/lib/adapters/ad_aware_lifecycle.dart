/// 앱 생명주기와 광고 화면을 함께 본다.
///
/// 광고 화면(AdActivity)이 앞에 오면 안드로이드는 게임에 onPause → onResume을 보낸다. 그걸 '백그라운드에 다녀왔다'로
/// 처리하면 엔진이 멈췄다가 다시 만들어지며 오프라인 보상(복귀 창)이 나왔다(2026-10-15 사용자 신고: "광고를 보고 돌아왔더니 골드를 줬다").
/// 광고가 떠 있는 동안(`adStarted` ~ `adEnded`)의 pause·resume은 무시한다 — 게임은 광고 뒤에서 계속 돈다.
class AdAwareLifecycle {
  AdAwareLifecycle({required this.onBackground, required this.onForeground});

  /// 진짜 백그라운드로 갈 때 (저장·엔진 멈춤·알림 예약·배경음 멈춤).
  final void Function() onBackground;

  /// 진짜 백그라운드에서 돌아올 때.
  final void Function() onForeground;

  bool _adShowing = false;
  bool _inBackground = false;

  bool get adShowing => _adShowing;

  void adStarted() => _adShowing = true;

  void adEnded() => _adShowing = false;

  void pause() {
    if (_adShowing || _inBackground) return;
    _inBackground = true;
    onBackground();
  }

  void resume() {
    if (!_inBackground) return; // 광고 때문에 무시한 pause의 짝 resume도 무시
    _inBackground = false;
    onForeground();
  }
}
