import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/ad_aware_lifecycle.dart';

void main() {
  late List<String> calls;
  late AdAwareLifecycle life;

  setUp(() {
    calls = [];
    life = AdAwareLifecycle(onBackground: () => calls.add('bg'), onForeground: () => calls.add('fg'));
  });

  test('보통의 백그라운드 왕복은 그대로 전달', () {
    life
      ..pause()
      ..resume();
    expect(calls, ['bg', 'fg']);
  });

  test('광고가 떠 있는 동안의 pause·resume은 무시 — 복귀 보상이 나오지 않는다', () {
    life
      ..adStarted()
      ..pause()
      ..resume()
      ..adEnded();
    expect(calls, isEmpty);
  });

  test('광고가 닫힌 뒤 늦게 오는 resume도 무시(짝 pause를 무시했으므로)', () {
    life
      ..adStarted()
      ..pause()
      ..adEnded()
      ..resume();
    expect(calls, isEmpty);
  });

  test('pause가 두 번 와도 백그라운드 처리는 한 번', () {
    life
      ..pause()
      ..pause()
      ..resume()
      ..resume();
    expect(calls, ['bg', 'fg']);
  });
}
