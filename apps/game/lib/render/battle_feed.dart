import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

/// 전장 라이브 입력. main이 `EngineHost.ticks`로 override하고, 전장을 만드는 쪽이
/// `BattleGame(feed: ref.read(battleFeedProvider))`로 넘긴다. null이면 데모 기록을 반복 재생한다.
final battleFeedProvider = Provider<Stream<RecordedTick>?>((_) => null);
