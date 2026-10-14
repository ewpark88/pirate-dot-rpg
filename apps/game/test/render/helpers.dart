import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

final tables = GameTables.load();
double get tickMs => tables.waves.tickMs.toDouble();

/// 테스트용 기록 한 틱. [enemies]는 (id, x) 목록, y는 100 고정.
RecordedTick tickOf(
  int i, {
  List<(int, double)> enemies = const [],
  List<GameEvent> events = const [],
  int hitStop = 0,
  int speed = 1,
}) => RecordedTick(
  BattleView(
    tick: i,
    shipHp: BigNum.from(60),
    shipHpMax: BigNum.from(60),
    enemies: [for (final (id, x) in enemies) EnemyView(id: id, kind: 'crab', x: x, y: 100, hpRatio: 1)],
    hitStopTicks: hitStop,
    speed: speed,
  ),
  events,
);

/// 적 하나가 매 틱 2px씩 다가오는 기록.
List<RecordedTick> marching(int n, {Map<int, List<GameEvent>> events = const {}}) => [
  for (var i = 0; i < n; i++) tickOf(i, enemies: [(1, 300 - 2.0 * i)], events: events[i] ?? const []),
];
