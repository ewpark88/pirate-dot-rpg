import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';

// 뒤로 가기 두 번 = 종료 (사용자 2026-10-18): 열린 창·시트가 있으면 뒤로 = 닫기(각 화면이 한다). 아무것도 없을 때
// 첫 뒤로 → '한 번 더 누르면 종료돼요' 토스트, [exitWindow] 안에 다시 → 저장 후 앱 종료. 탑·러시·던전 중에도 같은 규칙
// (종료하면 엔진이 다음 실행에 interrupted로 처리한다).

/// 두 번째 뒤로를 기다리는 시간.
const exitWindow = Duration(seconds: 2);

/// 종료 직전 저장(앱이 EngineHost.save로 덮는다). 없으면 앱이 내려갈 때의 pause 저장에 맡긴다.
final exitSaveProvider = Provider<Future<void> Function()?>((_) => null);

/// 앱 종료(시험이 덮는다).
final appExitProvider = Provider<Future<void> Function()>((_) => SystemNavigator.pop);

/// 마지막 '뒤로'를 누른 시각(종료 대기 중이면).
final _lastBackProvider = NotifierProvider<_LastBack, DateTime?>(_LastBack.new);

class _LastBack extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  // 시각 기록 — 동작이라 메서드로 둔다.
  // ignore: use_setters_to_change_properties
  void mark(DateTime? at) => state = at;
}

/// 홈 화면에서 닫을 것이 없을 때의 뒤로.
void backToExit(BuildContext context, WidgetRef ref) {
  final now = ref.read(clockProvider).now();
  final last = ref.read(_lastBackProvider);
  if (last != null && now.difference(last) <= exitWindow) {
    ref.read(_lastBackProvider.notifier).mark(null);
    unawaited(() async {
      await ref.read(exitSaveProvider)?.call();
      await ref.read(appExitProvider)();
    }());
    return;
  }
  ref.read(_lastBackProvider.notifier).mark(now);
  showSkinToast(context, AppLocalizations.of(context).uiBackToExit);
}
