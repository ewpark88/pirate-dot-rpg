import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/system_clock.dart';

/// 지금 시각 (순풍 남은 시간·복귀 보상). 테스트는 고정 시계로 덮는다.
final clockProvider = Provider<Clock>((_) => const SystemClock());

/// 테스트·운영자용 고정 시계.
class FixedClock implements Clock {
  FixedClock(this.time);

  DateTime time;

  @override
  DateTime now() => time;
}
