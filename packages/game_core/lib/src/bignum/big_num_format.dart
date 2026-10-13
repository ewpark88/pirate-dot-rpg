import 'dart:math' as math;

import 'package:game_core/src/bignum/big_num.dart';

/// 화면 표시: 1,000 미만은 정수, 이후 K·M·B·T, 그 뒤 aa·ab…. 언어와 무관하게 같다.
extension BigNumFormat on BigNum {
  String format() {
    if (isNegative) return '-${(-this).format()}';
    if (exponent < 3) return toDouble().floor().toString();
    final group = exponent ~/ 3;
    final value = mantissa * math.pow(10.0, exponent % 3);
    final digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    // 표시 자릿수 아래는 버린다(반올림하면 999.9K → 1000K가 된다).
    final scale = math.pow(10.0, digits);
    final shown = (value * scale + _epsilon).floor() / scale;
    var text = shown.toStringAsFixed(digits);
    if (text.contains('.')) text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    return '$text${_suffix(group)}';
  }
}

/// 3.33 × 100 = 332.99999… 같은 부동소수 오차 보정.
const _epsilon = 1e-6;

const _named = ['', 'K', 'M', 'B', 'T'];
const _alphabet = 26;
final int _a = 'a'.codeUnitAt(0);

String _suffix(int group) {
  if (group < _named.length) return _named[group];
  final n = group - _named.length;
  return String.fromCharCodes([_a + n ~/ _alphabet % _alphabet, _a + n % _alphabet]);
}
