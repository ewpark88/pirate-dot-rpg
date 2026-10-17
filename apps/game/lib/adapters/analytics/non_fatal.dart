import 'package:flutter/foundation.dart';

/// 비치명 오류 받는 곳(Crashlytics recordError(fatal: false)) — main.dart가 분석 SDK가 뜬 뒤 정한다. null이면 로그만.
typedef NonFatalSink = void Function(Object error, StackTrace? stack, String reason);

/// 지금 받는 곳. 시험은 가짜로 바꾸고 [resetNonFatal]로 되돌린다.
NonFatalSink? nonFatalSink;

final _sent = <String>{};

/// 잡은 예외를 조용히 삼키던 곳(광고·전원·알림·세이브·오디오)에서 부른다(docs/store/crash-anr.md 2절):
/// 늘 logcat에 남기고, 보고는 [reason]마다 앱 실행당 한 번만(같은 실패가 틱마다 나도 보고가 폭주하지 않게).
void reportNonFatal(Object error, StackTrace? stack, String reason) {
  debugPrint('$reason: $error');
  if (!_sent.add(reason)) return;
  final sink = nonFatalSink;
  if (sink == null) return;
  try {
    sink(error, stack, reason);
  } on Object catch (e) {
    debugPrint('non-fatal report failed: $e'); // 보고가 실패해도 앱은 돈다
  }
}

/// 시험용: 보낸 사유 기록과 받는 곳을 비운다.
@visibleForTesting
void resetNonFatal() {
  _sent.clear();
  nonFatalSink = null;
}
