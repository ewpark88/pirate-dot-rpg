import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 카드에 한 줄로 쓰는 짧은 선원 이름 (layout-v2-brief: 별명·앞말은 상세 창에서).
/// crew 파트의 `crew{Id}Short` 키 — 테이블 `nameKey`(`crew{Id}Name`)에서 끝만 바꿔 찾는다.
String shortCrewName(AppLocalizations l10n, CrewDef crew) =>
    tableText(l10n, '${crew.nameKey.substring(0, crew.nameKey.length - _nameSuffix.length)}Short');

const _nameSuffix = 'Name';
