import 'package:flutter/widgets.dart' show Locale;
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 카드에 한 줄로 쓰는 짧은 선원 이름 (layout-v2-brief: 별명·앞말은 상세 창에서).
/// 임시 규칙 — 짧은 이름 키(crew 파트, 경제 레인 소유)가 생기면 그 키로 바꾼다:
/// 영어는 ‘X the …’의 X, 한국어는 마지막 낱말(앞말 = 종·역할). ‘the’가 없는 이름(Crab Brothers / 꽃게 형제)은 그대로.
String shortCrewName(AppLocalizations l10n, CrewDef crew) {
  final full = tableText(l10n, crew.nameKey);
  final en = lookupAppLocalizations(const Locale('en'));
  final enFull = tableText(en, crew.nameKey);
  final the = enFull.indexOf(' the ');
  if (the < 0) return full;
  if (l10n.localeName == 'en') return enFull.substring(0, the);
  final space = full.lastIndexOf(' ');
  return space < 0 ? full : full.substring(space + 1);
}
