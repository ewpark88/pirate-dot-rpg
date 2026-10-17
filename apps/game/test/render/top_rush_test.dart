import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/top_fever_strike.dart';

/// 필살기 폭주(S1·S2 선장 필살기 3초): 컷인 뒤 3초 동안 폭주 1(발사체 굵게·불 꼬리·배 금빛 오라), 끝 0.5초에 사라짐.
void main() {
  test('폭주는 3초 동안 1, 끝에 0', () {
    final s = TopFeverStrike()..start(1000, 'octo', Offset.zero, const []);
    expect(s.rush(999), 0);
    expect(s.rush(1100), 1);
    expect(s.rush(1000 + 2600), closeTo(0.8, 1e-9));
    expect(s.rush(1000 + 3100), 0);
  });
}
