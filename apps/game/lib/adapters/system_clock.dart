import 'package:game_core/contracts.dart';

/// 실제 시계. 코어는 Clock 포트로만 시간을 본다.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
