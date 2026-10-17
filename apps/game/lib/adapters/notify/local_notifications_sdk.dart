import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pirate_dot/adapters/notify/notify_sdk.dart';
import 'package:pirate_dot/adapters/notify/notify_texts.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 실제 로컬 알림 (Android). iOS는 M6까지 아무것도 하지 않는다.
class LocalNotificationsSdk implements NotifySdk {
  static const _channelId = 'offline_full';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<bool> _init() async {
    if (_ready) return true;
    if (!Platform.isAndroid) return false;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    return _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> schedule({required int id, required DateTime at, required NotifyTexts texts}) async {
    if (!await _init()) return;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(_channelId, texts.channelName),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: texts.title,
      body: texts.body,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!await _init()) return;
    await _plugin.cancel(id: id);
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool?> permissionGranted() async {
    if (!await _init()) return null;
    return _android?.areNotificationsEnabled();
  }
}
