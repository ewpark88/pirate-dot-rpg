import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  group('BigNum 기본', () {
    test('정규화: 가수는 [1, 10)', () {
      final n = BigNum.from(12500);
      expect(n.mantissa, 1.25);
      expect(n.exponent, 4);
      expect(BigNum.fromParts(0.05, 3), BigNum.from(50));
    });

    test('저장 형식 왕복', () {
      for (final s in ['1.25e6', '1e0', '-3.5e-2', '9.99e300', '0e0']) {
        expect(BigNum.parse(s).toString(), s);
      }
      expect(BigNum.parse('42'), BigNum.from(42));
      expect(() => BigNum.parse('abc'), throwsFormatException);
    });

    test('double 범위를 넘는 수', () {
      final huge = BigNum.parse('1e400') * BigNum.parse('1e400');
      expect(huge.exponent, 800);
      expect(huge > BigNum.parse('9.9e799'), isTrue);
    });

    test('강화 비용 10 × 1.15^Lv', () {
      final cost = BigNum.powOf(1.15, 100).times(10);
      expect(cost.toDouble(), closeTo(10 * pow(1.15, 100), 1e-3 * 10 * pow(1.15, 100)));
    });

    test('크게 다른 수의 덧셈은 큰 쪽', () {
      expect(BigNum.parse('1e100') + BigNum.one, BigNum.parse('1e100'));
    });
  });

  group('표시', () {
    final cases = {
      '0e0': '0',
      '9.99e2': '999',
      '1e3': '1K',
      '1.24e4': '12.4K',
      '9.999e5': '999K',
      '1.5e6': '1.5M',
      '2e9': '2B',
      '3.33e12': '3.33T',
      '1e15': '1aa',
      '1e18': '1ab',
      '1e90': '1az',
      '1e93': '1ba',
      '-1.5e3': '-1.5K',
    };
    for (final c in cases.entries) {
      test('${c.key} → ${c.value}', () => expect(BigNum.parse(c.key).format(), c.value));
    }
  });

  group('속성 (무작위 3000개)', () {
    final rng = Random(7);
    double rand() => (rng.nextDouble() * 2 - 0.5) * pow(10, rng.nextInt(200) - 50);
    test('double 결과와 상대 오차 1e-6 이내', () {
      for (var i = 0; i < 3000; i++) {
        final a = rand();
        final b = rand();
        final A = BigNum.from(a);
        final B = BigNum.from(b);
        void check(BigNum got, double want) {
          if (want == 0 || !want.isFinite) return;
          expect((got.toDouble() - want).abs() / want.abs(), lessThan(1e-6), reason: '$a, $b');
        }

        check(A + B, a + b);
        check(A * B, a * b);
        if (b != 0) check(A / B, a / b);
        // double.compareTo는 -0.0 < 0.0으로 보지만 BigNum은 같은 0이다.
        expect(A.compareTo(B), a < b ? -1 : (a > b ? 1 : 0), reason: '$a vs $b');
      }
    });

    test('교환·결합법칙', () {
      for (var i = 0; i < 3000; i++) {
        final a = BigNum.from(rand().abs());
        final b = BigNum.from(rand().abs());
        final c = BigNum.from(rand().abs());
        expect((a + b).closeTo(b + a), isTrue);
        expect((a * b).closeTo(b * a), isTrue);
        expect(((a + b) + c).closeTo(a + (b + c), relTol: 1e-6), isTrue);
        expect(((a * b) * c).closeTo(a * (b * c)), isTrue);
      }
    });
  });
}
