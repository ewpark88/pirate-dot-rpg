import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:game_core/contracts.dart';
import 'package:pirate_dot/adapters/notify/notify_log.dart';
import 'package:pirate_dot/adapters/notify/notify_sdk.dart';
import 'package:pirate_dot/adapters/notify/notify_texts.dart';

/// 오프라인 보상 가득 알림 (스펙 platform-m4 b). 백그라운드로 갈 때 [fullAfter] 뒤 1건 예약, 돌아오면 취소.
/// 하루 [dailyMax]회 — **울릴 현지 날짜** 기준. 실패는 삼킨다(알림이 없어도 게임은 돈다).
class OfflineFullNotifier {
  OfflineFullNotifier({
    required this._sdk,
    required this._clock,
    required this.dir,
    required this.fullAfter,
    required this.minAway,
    required this.dailyMax,
    required this.enabled,
    required this.lang,
    DateTime Function(DateTime utc)? toLocal,
  }) : _toLocal = toLocal ?? ((t) => t.toLocal());

  static const _id = 1;

  final NotifySdk _sdk;
  final Clock _clock;
  final DateTime Function(DateTime) _toLocal;

  /// 기록 파일 폴더 (앱 지원 폴더).
  final Directory dir;

  /// `meta.offline.maxSec`.
  final Duration fullAfter;

  /// `meta.offline.minSec` — 이만큼 비운 첫 복귀에 권한을 묻는다.
  final Duration minAway;

  /// `meta.notifications.dailyMax`.
  final int dailyMax;

  /// `settings.notifications` (계약 반영 전엔 항상 true).
  final bool Function() enabled;

  /// `settings.lang`.
  final String Function() lang;

  Future<void> onPause() => _guard(() async {
    final log = await NotifyLog.read(dir);
    final now = _clock.now();
    log.pausedAt = now;
    final at = now.add(fullAfter);
    if (enabled() && _countOn(log, at) < dailyMax) {
      await _sdk.schedule(
        id: _id,
        at: at,
        texts: notifyTextsFor(lang(), hours: fullAfter.inHours),
      );
      log.rings.add(at);
    }
    await log.write(dir);
  });

  Future<void> onResume() => _guard(() async {
    final log = await NotifyLog.read(dir);
    final now = _clock.now();
    await _cancelPending(log, now);
    final away = log.pausedAt == null ? Duration.zero : now.difference(log.pausedAt!);
    log.pausedAt = null;
    if (!log.permissionAsked && away >= minAway) {
      log.permissionAsked = true;
      await log.write(dir); // 권한 창이 떠 있는 동안 죽어도 다시 묻지 않게 먼저 기록
      await _sdk.requestPermission();
    }
    await log.write(dir);
  });

  /// 설정에서 끄면 남은 예약을 바로 취소한다.
  Future<void> onSettingChanged({required bool enabled}) => _guard(() async {
    if (enabled) return;
    final log = await NotifyLog.read(dir);
    await _cancelPending(log, _clock.now());
    await log.write(dir);
  });

  Future<void> _cancelPending(NotifyLog log, DateTime now) async {
    await _sdk.cancel(_id);
    log.rings.removeWhere((r) => r.isAfter(now));
  }

  int _countOn(NotifyLog log, DateTime at) {
    final day = _toLocal(at);
    return log.rings.map(_toLocal).where((r) => r.year == day.year && r.month == day.month && r.day == day.day).length;
  }

  static Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } on Object catch (e) {
      debugPrint('notify: $e');
    }
  }
}
