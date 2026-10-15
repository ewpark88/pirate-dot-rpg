import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';

/// 전체 자릿수로 쓰는 가장 큰 지수 (그 위는 ‘m × 10^e’).
const _maxFullExponent = 20;

/// 세 자리 묶음 구분자 (숫자라 언어와 무관).
const _groupSeparator = ',';

/// 큰 수의 전체 값: 10^20 미만은 세 자리마다 쉼표, 그 위는 ‘1.25 × 10^24’ (계획 E11).
String fullBigNumText(AppLocalizations l10n, BigNum n) {
  if (n.exponent > _maxFullExponent) {
    final m = n.mantissa.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    // 생성된 함수의 인자 순서는 (exponent, mantissa)다.
    return l10n.uiNumberScientific(n.exponent, m);
  }
  // 가수의 유효 자리만 쓰고 나머지는 0 (double 정밀도 이상은 의미 없다).
  final digits = BigInt.from((n.mantissa * 1e15).round()) * BigInt.from(10).pow(n.exponent) ~/ BigInt.from(10).pow(15);
  final s = digits.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(_groupSeparator);
    out.write(s[i]);
  }
  return out.toString();
}

/// 큰 수 글자 (`BigNum.format`, 예: 1.25M). 길게 누르면 전체 자릿수 설명이 뜬다.
class BigNumText extends StatelessWidget {
  const BigNumText(this.value, {this.style, super.key});

  final BigNum value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: fullBigNumText(AppLocalizations.of(context), value),
    triggerMode: TooltipTriggerMode.longPress,
    child: Text(value.format(), style: style),
  );
}
