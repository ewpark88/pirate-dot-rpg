import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';

/// 비율(0.17)을 퍼센트 숫자로.
const _percent = 100;

/// 배율·퍼센트 표시 자릿수.
const _fractionDigits = 2;

/// 소수 둘째 자리까지, 끝의 0과 점은 지운다 (1.90 → 1.9, 17.00 → 17).
String shortDecimal(double value) => value.toStringAsFixed(_fractionDigits).replaceFirst(RegExp(r'\.?0+$'), '');

/// 0.17 → "17%".
String percentText(AppLocalizations l10n, double ratio) => l10n.uiPercent(shortDecimal(ratio * _percent));

/// 배 부위 효과 표시: 공격력·HP는 큰 수, 속도·골드는 배율, 치명타는 퍼센트.
String partEffectText(AppLocalizations l10n, ShipPartDef def, BigNum effect) => switch (def.stat) {
  'speed' || 'gold' => l10n.uiEffectMultiplier(shortDecimal(effect.toDouble())),
  'critChance' => percentText(l10n, effect.toDouble()),
  _ => effect.format(),
};
