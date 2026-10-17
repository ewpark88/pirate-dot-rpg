/// 엔진 히트스톱 거르기(S5 자료: 탑에서 초당 3.6회 멈칫 → '조잡'): 멈춤 구간(hitStopTicks)을 렌더 재생에서
/// [minGapMs]마다 한 번만(초당 최대 1.5회) 실제로 멈추고, 나머지는 빨리 흘려보낸다([fastMul]배). 필살기(ultimate)는 늘 멈춤.
/// 엔진 자리는 그대로 — 멈춘 틱을 짧게 보일 뿐이다.
class HitStopGate {
  static const minGapMs = 667.0;
  static const fastMul = 10.0;

  /// 재생 시계(ms, RecordingPlayer.advance가 더한다).
  double clock = 0;
  double _last = -1000000000;
  int _runEnd = -1;
  bool _fast = false;
  int honored = 0; // 실제로 멈춘 횟수(시험)

  /// 틱 [i]부터 시작하는 멈춤 구간을 빨리 넘길지 — 구간 첫 틱에서 한 번 정한다.
  bool fast(int i, bool Function(int i) frozen, String? Function(int i) reasonAt) {
    if (i > _runEnd || i < _runEnd - 64) {
      var e = i;
      while (e - i < 64 && frozen(e + 1)) {
        e++;
      }
      _runEnd = e;
      final stop = clock - _last >= minGapMs || clock < _last || reasonAt(i) == 'ultimate';
      if (stop) {
        _last = clock;
        honored++;
      }
      _fast = !stop;
    }
    return _fast;
  }
}
