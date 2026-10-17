import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/analytics/non_fatal.dart';

void main() {
  tearDown(resetNonFatal);

  test('비치명 보고: 받는 곳이 없으면 로그만, 있으면 사유마다 실행당 한 번 · 보고가 던져도 앱은 계속', () {
    reportNonFatal(StateError('x'), null, 'ads: show failed'); // 받는 곳 없음 — 조용히
    final got = <String>[];
    nonFatalSink = (e, s, reason) => got.add(reason);
    reportNonFatal(StateError('a'), null, 'notify');
    reportNonFatal(StateError('b'), null, 'notify');
    reportNonFatal(StateError('c'), StackTrace.current, 'save: io');
    expect(got, ['notify', 'save: io']);
    nonFatalSink = (e, s, reason) => throw StateError('crashlytics down');
    expect(() => reportNonFatal(StateError('d'), null, 'power: setFrameRate failed'), returnsNormally);
  });
}
