import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/system_clock.dart';

/// 화면이 보는 상태는 이 파일의 provider뿐이다. 화면은 GameState를 구독하고, 버튼은 CommandSink로 Command만 보낸다.

/// 앱에 심은 테이블.
final tablesProvider = Provider<GameTables>((ref) => GameTables.load());

/// 첫 상태. 테스트·운영자 모드는 fixtures/states 샘플로 덮어쓴다.
// TODO(main): 엔진을 앱에 연결하면 세이브(SaveStore)에서 읽은 상태로 바꾼다.
final initialGameStateProvider = Provider<GameState>(
  (ref) => GameState.newGame(playerId: 'local', seed: 0, now: const SystemClock().now()),
);

/// 화면이 구독하는 현재 상태.
final gameStateProvider = NotifierProvider<GameStateController, GameState>(GameStateController.new);

class GameStateController extends Notifier<GameState> {
  @override
  GameState build() => ref.watch(initialGameStateProvider);

  /// 엔진 스냅샷 또는 운영자 샘플 상태로 바꾼다. (호출하는 쪽에서 동작으로 읽히도록 setter 대신 메서드)
  // ignore: use_setters_to_change_properties
  void replace(GameState next) => state = next;
}

/// 버튼이 Command를 보내는 곳.
// TODO(main): 엔진을 앱에 연결하면 GameEngine.enqueue로 보내는 구현으로 바꾼다.
final commandSinkProvider = Provider<CommandSink>((ref) => CommandLog());

/// UI → 엔진 입력 통로. UI는 상태를 직접 바꾸지 않는다.
abstract interface class CommandSink {
  void send(Command command);
}

/// 보낸 명령을 모으기만 한다 (엔진 연결 전 기본값, 테스트).
class CommandLog implements CommandSink {
  final List<Command> sent = [];

  @override
  void send(Command command) => sent.add(command);
}
