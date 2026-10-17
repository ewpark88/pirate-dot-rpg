/// 해적도트 원정대 데이터 테이블. 수치는 tables/*.json에만 있고 여기서 읽는다.
library;

export 'src/game_tables.dart';
export 'src/models/battle_tables.dart';
export 'src/models/common.dart' show JsonReader, TableFormatException, TableValidationException;
export 'src/models/crew_tables.dart';
export 'src/models/economy_tables.dart';
export 'src/models/legend_tables.dart';
export 'src/models/region_tables.dart';
export 'src/models/render_tables.dart';
export 'src/models/skill_tables.dart';
export 'src/models/story_tables.dart';
export 'src/tables.g.dart' show rawTables;
