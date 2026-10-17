import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 순간 안내 (S1 2026-10-18 '오늘 생긴 기능 첫 안내'): 상태로는 알 수 없는 순간(대군 습격 첫 파 · 2배속 켜짐)을 잠깐 켜 둬
// 가이드 줄(guideQueueProvider)이 고르게 한다. 새 기능 안내([featureGuideIds])는 한 실행에 하나만.

/// 오늘 생긴 기능 첫 안내 — 한 실행에 하나(나머지는 다음 실행에서 조건이 맞는 순간).
const featureGuideIds = {'guide.horde', 'guide.achievement', 'guide.speed'};

/// 지금 켜진 순간 id(guide.*). 몇 초 뒤 저절로 꺼진다.
final guideMomentsProvider = NotifierProvider<GuideMoments, Set<String>>(GuideMoments.new);

class GuideMoments extends Notifier<Set<String>> {
  final _timers = <String, Timer>{};

  @override
  Set<String> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
    });
    return const {};
  }

  /// [id]를 [duration] 동안 켠다.
  void flash(String id, {Duration duration = const Duration(seconds: 8)}) {
    _timers[id]?.cancel();
    state = {...state, id};
    _timers[id] = Timer(duration, () => state = {...state}..remove(id));
  }
}

/// 가이드 말 잠깐 멈춤 (환영 카드 순간 — S3 카드 연출이 전장 가운데에서 끝날 때까지, S3 c12ced0a).
final guideHoldProvider = NotifierProvider<GuideHold, bool>(GuideHold.new);

class GuideHold extends Notifier<bool> {
  Timer? _end;

  @override
  bool build() {
    ref.onDispose(() => _end?.cancel());
    return false;
  }

  /// 타이머를 멈춘다(접은 쪽 화면이 사라질 때 — 타이머가 남지 않게). 화면 정리 중이라 상태는 바꾸지 않는다.
  void release() {
    _end?.cancel();
    _end = null;
  }

  /// [duration] 동안 말을 접는다.
  void hold(Duration duration) {
    _end?.cancel();
    state = true;
    _end = Timer(duration, () => state = false);
  }
}
