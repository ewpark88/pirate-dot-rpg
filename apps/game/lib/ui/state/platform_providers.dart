import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/adapters/file_save_store.dart';
import 'package:pirate_dot/adapters/notify/offline_full_notifier.dart';

/// 오프라인 가득 알림 어댑터 (null = 없음). 앱(main.dart)이 실제 어댑터로 덮는다. 운영자 패널의 '알림 10초 뒤'가 쓴다.
final notifierProvider = Provider<OfflineFullNotifier?>((_) => null);

/// 저장 실패 알림 (`FileSaveStore.failure`: diskFull·io, 성공하면 null). 앱(main.dart)이 덮는다. 기본은 늘 null.
final saveFailureProvider = Provider<ValueListenable<SaveFailure?>>((_) => ValueNotifier<SaveFailure?>(null));
