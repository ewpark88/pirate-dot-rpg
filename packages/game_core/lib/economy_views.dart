/// 경제 화면용 값 타입 (UI·테스트가 가짜 값을 만들 때). game_core.dart와 따로 둔 것은
/// ui 레인의 옛 임시 타입과 이름이 겹치지 않게 하려고 — UI가 옮겨 오면 game_core.dart로 합칠 수 있다.
library;

export 'src/economy/daily.dart' show AttendanceView, QuestView;
export 'src/economy/meta_views.dart' show CollectionBonus, GoalKind, NextGoal;
