import 'dart:math' as math;

import 'package:meta/meta.dart';

/// 방치형용 큰 수: 가수(double, |m| ∈ [1, 10)) × 10^지수(int). 골드·HP·피해는 모두 이 타입.
///
/// 0은 m = 0, e = 0. 저장 형식은 `"1.25e6"`.
@immutable
class BigNum implements Comparable<BigNum> {
  const BigNum._(this.mantissa, this.exponent);

  /// 일반 수에서 만든다.
  factory BigNum.from(num value) => BigNum.fromParts(value.toDouble(), 0);

  /// 정규화하며 만든다.
  factory BigNum.fromParts(double mantissa, int exponent) {
    if (mantissa == 0 || mantissa.isNaN) return zero;
    if (mantissa.isInfinite) throw ArgumentError('BigNum: 무한대는 표현하지 않습니다');
    final shift = (math.log(mantissa.abs()) / math.ln10).floor();
    var m = mantissa / math.pow(_base, shift);
    var e = exponent + shift;
    // 부동소수 반올림으로 9.999…→10이 되는 경우 보정.
    if (m.abs() >= _base) {
      m /= _base;
      e += 1;
    } else if (m.abs() < 1) {
      m *= _base;
      e -= 1;
    }
    return BigNum._(m, e);
  }

  /// `"1.25e6"`, `"42"`, `"-3.5e-2"`를 읽는다. 틀리면 [FormatException].
  factory BigNum.parse(String text) {
    final s = text.trim();
    final i = s.indexOf(RegExp('[eE]'));
    final m = double.tryParse(i < 0 ? s : s.substring(0, i));
    final e = i < 0 ? 0 : int.tryParse(s.substring(i + 1));
    if (m == null || e == null || m.isInfinite || m.isNaN) {
      throw FormatException('BigNum 형식이 아닙니다', text);
    }
    return BigNum.fromParts(m, e);
  }

  /// [base]^[p]. 강화 비용 `10 × 1.15^Lv` 같은 식에 쓴다.
  factory BigNum.powOf(num base, num p) => BigNum.from(base).pow(p);

  static const zero = BigNum._(0, 0);
  static const one = BigNum._(1, 0);

  static const double _base = 10;

  /// double 정밀도(약 15자리)를 넘는 지수 차이는 작은 쪽을 버린다.
  static const int _precisionDigits = 17;

  final double mantissa;
  final int exponent;

  bool get isZero => mantissa == 0;
  bool get isNegative => mantissa < 0;

  /// log10(|x|). 0이면 음의 무한대.
  double get log10 => isZero ? double.negativeInfinity : exponent + math.log(mantissa.abs()) / math.ln10;

  /// double로. 범위를 넘으면 ±infinity.
  double toDouble() => mantissa * math.pow(_base, exponent);

  BigNum operator +(BigNum o) {
    if (isZero) return o;
    if (o.isZero) return this;
    final (big, small) = exponent >= o.exponent ? (this, o) : (o, this);
    final diff = big.exponent - small.exponent;
    if (diff > _precisionDigits) return big;
    return BigNum.fromParts(big.mantissa + small.mantissa / math.pow(_base, diff), big.exponent);
  }

  BigNum operator -() => BigNum._(-mantissa, exponent);

  BigNum operator -(BigNum o) => this + (-o);

  BigNum operator *(BigNum o) => BigNum.fromParts(mantissa * o.mantissa, exponent + o.exponent);

  BigNum operator /(BigNum o) {
    if (o.isZero) throw UnsupportedError('BigNum: 0으로 나눌 수 없습니다');
    return BigNum.fromParts(mantissa / o.mantissa, exponent - o.exponent);
  }

  /// 일반 수를 곱한다.
  BigNum times(num k) => BigNum.fromParts(mantissa * k, exponent);

  /// 거듭제곱. 음수 밑은 다루지 않는다.
  BigNum pow(num p) {
    if (isZero) return p == 0 ? one : zero;
    if (isNegative) throw ArgumentError('BigNum.pow: 음수 밑');
    final l = log10 * p;
    final e = l.floor();
    return BigNum.fromParts(math.pow(_base, l - e).toDouble(), e);
  }

  @override
  int compareTo(BigNum o) {
    if (isNegative != o.isNegative) return isNegative ? -1 : 1;
    if (isZero || o.isZero) return mantissa.compareTo(o.mantissa);
    final sign = isNegative ? -1 : 1;
    if (exponent != o.exponent) return sign * exponent.compareTo(o.exponent);
    return mantissa.compareTo(o.mantissa);
  }

  bool operator <(BigNum o) => compareTo(o) < 0;
  bool operator <=(BigNum o) => compareTo(o) <= 0;
  bool operator >(BigNum o) => compareTo(o) > 0;
  bool operator >=(BigNum o) => compareTo(o) >= 0;

  static BigNum max(BigNum a, BigNum b) => a >= b ? a : b;
  static BigNum min(BigNum a, BigNum b) => a <= b ? a : b;

  /// 상대 오차 [relTol] 안에서 같은가 (테스트·밸런스 비교용).
  bool closeTo(BigNum o, {double relTol = 1e-9}) {
    if (isZero || o.isZero) return (this - o).mantissa.abs() < relTol;
    final d = this - o;
    return d.isZero || d.log10 - math.max(log10, o.log10) < math.log(relTol) / math.ln10;
  }

  @override
  bool operator ==(Object other) => other is BigNum && other.mantissa == mantissa && other.exponent == exponent;

  @override
  int get hashCode => Object.hash(mantissa, exponent);

  /// 저장 형식 `"1.25e6"`.
  @override
  String toString() {
    final m = mantissa == mantissa.truncateToDouble() ? mantissa.toInt().toString() : mantissa.toString();
    return '${m}e$exponent';
  }

  String toJson() => toString();
}
