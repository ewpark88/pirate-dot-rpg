import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 알림 어댑터 전용 기록 `notify.json` (세이브와 별개 — 세이브 스키마 무변경).
class NotifyLog {
  NotifyLog({List<DateTime>? rings, this.pausedAt, this.permissionAsked = false}) : rings = rings ?? [];

  /// 예약했거나 울린 시각(UTC). 울리기 전에 취소되면 빠진다.
  final List<DateTime> rings;
  DateTime? pausedAt;
  bool permissionAsked;

  static const _keep = 14;

  static File _file(Directory dir) => File(p.join(dir.path, 'notify.json'));

  /// 없거나 깨졌으면 빈 기록.
  static Future<NotifyLog> read(Directory dir) async {
    try {
      final j = jsonDecode(await _file(dir).readAsString()) as Map<String, Object?>;
      return NotifyLog(
        rings: [for (final s in j['rings']! as List<Object?>) DateTime.parse(s! as String)],
        pausedAt: switch (j['pausedAt']) {
          final String s => DateTime.parse(s),
          _ => null,
        },
        permissionAsked: j['permissionAsked']! as bool,
      );
    } on Object {
      return NotifyLog();
    }
  }

  Future<void> write(Directory dir) async {
    if (rings.length > _keep) rings.removeRange(0, rings.length - _keep);
    await dir.create(recursive: true);
    await _file(dir).writeAsString(
      jsonEncode({
        'rings': [for (final r in rings) r.toIso8601String()],
        'pausedAt': pausedAt?.toIso8601String(),
        'permissionAsked': permissionAsked,
      }),
    );
  }
}
