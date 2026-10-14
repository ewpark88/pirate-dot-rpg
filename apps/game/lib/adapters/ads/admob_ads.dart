import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:game_core/contracts.dart';
import 'package:pirate_dot/adapters/ads/ads_sdk.dart';

/// 지연 실행. 테스트는 기록만 하고 직접 부른다.
typedef Schedule = void Function(Duration delay, void Function() run);

void _timerSchedule(Duration d, void Function() run) => Timer(d, run);

/// AdMob 보상형 + UMP (스펙 platform-m4 a). 보상형은 형식이 하나라 로드된 광고 1개를 모든 장치가 공유한다.
/// 일일 한도는 세지 않는다(코어·UI 몫). 실패는 모두 삼키고 "준비 안 됨"으로 남는다.
class AdMobAds implements AdsPort {
  AdMobAds(this._sdk, {this._schedule = _timerSchedule});

  static const _firstRetry = Duration(seconds: 30);
  static const _maxRetry = Duration(minutes: 10);

  final AdsSdk _sdk;
  final Schedule _schedule;
  final _ready = ValueNotifier<bool>(false);
  final _consent = ValueNotifier<bool>(false);
  bool _started = false;
  bool _loading = false;
  Duration _retry = _firstRetry;

  /// 광고를 바로 보여 줄 수 있는가 (장치 구분 없음). `adsReadyProvider` override가 듣는다.
  ValueListenable<bool> get ready => _ready;

  /// UMP 동의로 광고 요청이 가능한가. EU Analytics 수집도 이것에 묶는다(S1 결정 ②).
  ValueListenable<bool> get consent => _consent;

  bool get privacyOptionsRequired => _started && _sdk.privacyOptionsRequired;

  Future<void> showPrivacyOptions() => _guard(_sdk.showPrivacyOptions);

  /// 동의 → 초기화 → 첫 로드. 첫 프레임 뒤에 부른다(UMP 폼). 실패해도 예외를 내지 않는다.
  Future<void> start() async {
    try {
      _consent.value = await _sdk.gatherConsent();
      if (!_consent.value) return;
      await _sdk.initialize();
      _started = true;
    } on Object catch (e) {
      debugPrint('ads: start failed $e');
      return;
    }
    await _load();
  }

  @override
  bool isReady(AdPlacement placement) => _ready.value;

  @override
  Future<AdResult> show(AdPlacement placement) async {
    if (!_ready.value) return AdResult.notLoaded;
    _ready.value = false;
    AdResult result;
    try {
      result = switch (await _sdk.show()) {
        AdShowOutcome.rewarded => AdResult.rewarded,
        AdShowOutcome.dismissed => AdResult.dismissed,
        AdShowOutcome.failed => AdResult.failed,
      };
    } on Object catch (e) {
      debugPrint('ads: show failed $e');
      result = AdResult.failed;
    }
    unawaited(_load());
    return result;
  }

  Future<void> _load() async {
    if (!_started || _loading || _ready.value) return;
    _loading = true;
    var ok = false;
    try {
      ok = await _sdk.load();
    } on Object catch (e) {
      debugPrint('ads: load failed $e');
    }
    _loading = false;
    if (ok) {
      _retry = _firstRetry;
      _ready.value = true;
      return;
    }
    final wait = _retry;
    _retry = Duration(microseconds: min(_retry.inMicroseconds * 2, _maxRetry.inMicroseconds));
    _schedule(wait, () => unawaited(_load()));
  }

  static Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } on Object catch (e) {
      debugPrint('ads: $e');
    }
  }
}
