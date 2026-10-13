import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 게임 엔진 계약. 앱·CLI·테스트는 이 인터페이스로만 엔진을 만난다.
abstract interface class GameEngine {
  /// 현재 상태 스냅샷.
  GameState get state;

  /// 고정 틱 길이 (waves.json tickMs, 기본 50ms = 20Hz).
  Duration get tickLength;

  /// 명령을 넣는다. 다음 [tick]에서 적용된다.
  void enqueue(Command command);

  /// 한 틱 진행. 히트스톱 중이면 시간은 흐르지 않고 남은 히트스톱만 준다.
  void tick();

  /// [ticks]번 진행 (배속 시뮬·테스트).
  void advance(int ticks);

  /// 쌓인 이벤트를 꺼내고 비운다.
  List<GameEvent> drainEvents();
}

/// 레인이 규칙을 끼워 넣는 자리. 엔진은 시스템을 순서대로 부른다.
///
/// - 전투 레인: packages/game_core/lib/src/battle/의 BattleSystem
/// - 경제 레인: packages/game_core/lib/src/economy/의 EconomySystem
abstract interface class GameSystem {
  /// [command]를 처리하면 새 상태를, 내 담당이 아니면 null을 돌려준다.
  GameState? handle(GameState state, Command command, SystemContext ctx);

  /// 매 틱 호출된다 (히트스톱 중 제외).
  GameState update(GameState state, SystemContext ctx);
}

/// 시스템이 쓰는 도구 모음. 시스템은 이것 외의 바깥 세계를 모른다.
class SystemContext {
  SystemContext({required this.tables, required this.clock, required this.rng, required this.onEvent});

  final GameTables tables;
  final Clock clock;
  final Rng rng;

  /// 엔진이 이벤트를 모으는 곳. 시스템은 [emit]을 쓴다.
  final void Function(GameEvent) onEvent;

  /// 지금 처리 중인 틱 번호.
  int tick = 0;

  void emit(GameEvent event) => onEvent(event);
}
