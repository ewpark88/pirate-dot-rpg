// 무거운 화면 조각의 build 횟수 (디버그·테스트 전용 — assert 안에서만 세므로 배포 빌드에선 없다).
// sheet_perf_test가 '엔진 틱 100번 동안 시트 목록이 몇 번 다시 지어지나'를 시간 대신 횟수로 잰다(PC 부하에 흔들리지 않게).

/// 조각 이름 → build 횟수.
final Map<String, int> debugBuildCounts = {};

/// [id]의 build 한 번을 센다 (assert가 꺼진 배포 빌드에선 아무것도 안 한다).
void countBuild(String id) {
  // 디버그에서만 세는 관용구(항상 참) — 메시지 문구는 화면에 안 나온다.
  // ignore: prefer_asserts_with_message
  assert(() {
    debugBuildCounts[id] = (debugBuildCounts[id] ?? 0) + 1;
    return true;
  }());
}
