package repo.dot.pirate

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // 첫 화면에서 BACK(Flutter 내비게이터가 더 닫을 게 없을 때)은 앱을 끄지 않고 뒤로 보낸다 — 흔한 게임 관행.
    // 끄면 같은 프로세스에서 엔진을 새로 띄우게 되는데, 그 경로가 스플래시에서 멈추는 문제가 있었다(2026-10-15 실기기).
    // 시트·창은 Flutter가 먼저 닫으므로 이 함수까지 오지 않는다.
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }

    // Android 16(API 36) 예측형 뒤로 가기에서는 위 경로를 거치지 않고 앱이 finish()를 부른다(logcat: wm_finish_activity app-request).
    // 작업의 맨 아래(첫 화면)에서 끝내려 하면 대신 뒤로 보낸다. 시스템이 메모리 때문에 없애는 경우는 finish()를 거치지 않는다.
    override fun finish() {
        if (isTaskRoot) {
            moveTaskToBack(true)
        } else {
            super.finish()
        }
    }
}
