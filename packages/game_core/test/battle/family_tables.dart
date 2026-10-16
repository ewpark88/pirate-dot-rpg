import 'dart:convert';

import 'package:game_data/game_data.dart';

/// 계열 기본 규칙을 재는 테스트용 표: 선원 개성 v2(crews `aim`, skills `traitScale`)를 뺀 사본.
/// 실제 표에는 선원마다 조준·연사·탄이 들어 있어, 계열 사다리·범위·전설 기본 값 테스트는 이 표로 본다.
GameTables familyTables() {
  final raw = Map<String, String>.of(rawTables);
  final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
  for (final c in crews['crews'] as List) {
    (c as Map<String, dynamic>).remove('aim');
  }
  raw['crews'] = jsonEncode(crews);
  final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>..remove('traitScale');
  for (final fam in (skills['families'] as List).cast<Map<String, dynamic>>()) {
    (fam['attack'] as Map<String, dynamic>).remove('behavior'); // 계열 v3 연출 타이밍(연사 묶음·튕김 지연 등) 없이
  }
  raw['skills'] = jsonEncode(skills);
  return GameTables.load(raw);
}
