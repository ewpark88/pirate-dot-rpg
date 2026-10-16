// 프레임당 그리기 호출 수 세기 (S1 절전·CPU 점검) — 탑다운 부하 테스트가 쓴다.
import 'dart:ui';

/// 그리기 호출만 센다 (실제로 그리지 않는다).
class CountingCanvas implements Canvas {
  int calls = 0;
  final byName = <String, int>{};
  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    if (n.contains('draw') || n.contains('clip')) {
      calls++;
      byName[n] = (byName[n] ?? 0) + 1;
    }
    return null;
  }
}
