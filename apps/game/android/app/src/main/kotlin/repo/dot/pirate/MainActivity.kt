package repo.dot.pirate

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

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

    // 발열 대책(2026-10-17 실기기 S24: 10분에 배터리 45℃·SEVERE, 120Hz): 화면 주사율 요청·발열 상태 알림(power_channel.dart).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "pirate_dot/power").setMethodCallHandler { call, result ->
            when (call.method) {
                "setFrameRate" -> {
                    setFrameRate((call.arguments as Number).toFloat())
                    result.success(null)
                }
                "thermalStatus" -> result.success(thermalStatus())
                "keepScreenOn" -> result.success(
                    window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0,
                )
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "pirate_dot/thermal").setStreamHandler(ThermalStream(this))
    }

    // 같은 해상도 모드 중 hz에 가장 가까운 주사율로(120Hz 기기에서 60·30 요청). 없으면 그대로.
    private fun setFrameRate(hz: Float) {
        @Suppress("DEPRECATION")
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay) ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .minByOrNull { abs(it.refreshRate - hz) } ?: return
        val attrs = window.attributes
        attrs.preferredDisplayModeId = best.modeId
        attrs.preferredRefreshRate = best.refreshRate
        window.attributes = attrs
    }

    // PowerManager 발열 단계(0 없음 … 6 꺼짐), API 29 미만은 0.
    private fun thermalStatus(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            (getSystemService(Context.POWER_SERVICE) as PowerManager).currentThermalStatus
        } else {
            0
        }
}

// 발열 단계가 바뀔 때마다 Dart로(API 29+).
private class ThermalStream(private val context: Context) : EventChannel.StreamHandler {
    private var listener: Any? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val l = PowerManager.OnThermalStatusChangedListener { status -> events.success(status) }
        pm.addThermalStatusListener(l)
        listener = l
    }

    override fun onCancel(arguments: Any?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val l = listener as? PowerManager.OnThermalStatusChangedListener ?: return
        (context.getSystemService(Context.POWER_SERVICE) as PowerManager).removeThermalStatusListener(l)
        listener = null
    }
}
