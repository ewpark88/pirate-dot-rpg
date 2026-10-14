import 'dart:math' as math;

// 단위 변환 상수. 밸런스 수치가 아니라서 테이블에 두지 않는다.
// battle/·economy/는 숫자 리터럴을 쓸 수 없으므로(tool/check) 여기서 가져다 쓴다.

/// 절반 (폭·각도의 반).
const double half = 0.5;

/// 도 → 라디안.
const double radiansPerDegree = math.pi / 180;

/// 밀리초 → 초.
const double secondsPerMillisecond = 1 / Duration.millisecondsPerSecond;
