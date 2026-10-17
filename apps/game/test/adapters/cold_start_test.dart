import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/analytics/deferred_analytics.dart';
import 'package:pirate_dot/adapters/analytics/noop_analytics.dart';
import 'package:pirate_dot/adapters/analytics/sdk_analytics.dart';
import 'package:pirate_dot/adapters/audio/audio_adapter.dart';

import 'analytics_test.dart' show FakeAnalyticsSdk;
import 'audio_adapter_test.dart' show FakeAudioSdk;

/// 콜드 스타트(docs/store/cold-start.md): 분석·음원 목록을 runApp 앞에서 기다리지 않는다.
class _SlowListSdk extends FakeAudioSdk {
  _SlowListSdk(super.files);

  final gate = Completer<Set<String>>();

  @override
  Future<Set<String>> listAssets() => gate.future;
}

void main() {
  test('DeferredAnalytics: 붙기 전 호출은 순서대로 쌓았다가 붙는 순간 보낸다 · 상한 넘치면 오래된 것부터 버림', () {
    final sdk = FakeAnalyticsSdk();
    final a = DeferredAnalytics(maxPending: 3)
      ..log('a')
      ..log('b')
      ..setCrashKey('scene', 'tower')
      ..setCollection(enabled: true); // 4번째 → 'a' 버림
    expect(sdk.events, isEmpty);
    a.attach(SdkAnalytics(sdk));
    expect(sdk.events.keys, ['b']);
    expect(sdk.crashKeys['scene'], 'tower');
    expect(sdk.collection, isTrue);
    a.log('c'); // 붙은 뒤엔 바로
    expect(sdk.events.keys, ['b', 'c']);
    DeferredAnalytics()
      ..log('x')
      ..attach(const NoopAnalytics()); // 실패(Noop)여도 조용히
  });

  test('AudioAdapter.later: 목록이 오기 전엔 무음, 오면 그 사이 정한 배경음·환경음을 그때 튼다', () async {
    final sdk = _SlowListSdk({'bgm/a.ogg', 'amb/wind.ogg', 'sfx/hit.ogg'});
    final a = AudioAdapter.later(sdk)
      ..setVolumes(sfx: 1, bgm: 1)
      ..playBgm('a')
      ..playAmbient('wind')
      ..playSfx('hit');
    expect(sdk.bgm, isEmpty);
    expect(sdk.sfx, isEmpty);
    sdk.gate.complete({'bgm/a.ogg', 'amb/wind.ogg', 'sfx/hit.ogg'});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(sdk.bgm, ['bgm/a.ogg']);
    expect(sdk.ambient, ['play amb/wind.ogg']);
    a.playSfx('hit');
    expect(sdk.sfx, hasLength(1), reason: '목록이 온 뒤의 효과음은 난다');
  });
}
