import 'package:pirate_dot/adapters/notify/notify_texts.dart';

/// flutter_local_notifications를 감싼 얇은 경계. 실제 구현은 `local_notifications_sdk.dart`, 테스트는 가짜.
abstract interface class NotifySdk {
  /// [at](UTC)에 한 번 울리는 알림. 정확한 알람 권한 없이(inexact) — 몇 분 늦어도 괜찮다.
  Future<void> schedule({required int id, required DateTime at, required NotifyTexts texts});

  Future<void> cancel(int id);

  /// Android 13+ `POST_NOTIFICATIONS`. 허용되면 true.
  Future<bool> requestPermission();

  /// 지금 알림이 켜져 있나(시스템 설정·권한) — true 허용 · false 꺼짐 · null 모름(Android 아님).
  Future<bool?> permissionGranted();
}
