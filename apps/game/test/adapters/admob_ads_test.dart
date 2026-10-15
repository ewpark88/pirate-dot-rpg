import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/ads/ad_unit_ids.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/adapters/ads/ads_sdk.dart';
import 'package:pirate_dot/adapters/ads/no_ads.dart';

class FakeAdsSdk implements AdsSdk {
  bool consent = true;
  bool initThrows = false;
  final loadResults = <bool>[];
  AdShowOutcome showOutcome = AdShowOutcome.rewarded;
  int loads = 0;
  int shows = 0;
  int inits = 0;

  @override
  Future<bool> gatherConsent() async => consent;

  @override
  Future<void> initialize() async {
    inits++;
    if (initThrows) throw StateError('sdk');
  }

  @override
  Future<bool> load() async {
    loads++;
    return loadResults.isEmpty || loadResults.removeAt(0);
  }

  @override
  Future<AdShowOutcome> show() async {
    shows++;
    return showOutcome;
  }

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

void main() {
  late FakeAdsSdk sdk;
  late List<Duration> scheduled;
  late List<void Function()> pending;
  late AdMobAds ads;

  setUp(() {
    sdk = FakeAdsSdk();
    scheduled = [];
    pending = [];
    ads = AdMobAds(
      sdk,
      schedule: (d, f) {
        scheduled.add(d);
        pending.add(f);
      },
    );
  });

  Future<void> runPending() async {
    final fs = [...pending];
    pending.clear();
    for (final f in fs) {
      f();
    }
    await pumpEventQueue();
  }

  test('1. 동의 전엔 로드하지 않는다', () async {
    sdk.consent = false;
    await ads.start();
    expect(sdk.loads, 0);
    expect(sdk.inits, 0);
    expect(ads.isReady(AdPlacement.chest), isFalse);
    expect(ads.ready.value, isFalse);
  });

  test('2. 동의·로드 성공이면 모든 장치가 준비', () async {
    await ads.start();
    expect(ads.isReady(AdPlacement.chest), isTrue);
    expect(ads.isReady(AdPlacement.offline), isTrue);
    expect(ads.ready.value, isTrue);
  });

  test('3. 로드 안 됐으면 notLoaded, SDK show 안 부름', () async {
    sdk.loadResults.add(false);
    await ads.start();
    expect(await ads.show(AdPlacement.chest), AdResult.notLoaded);
    expect(sdk.shows, 0);
  });

  test('4. 보상 후 닫힘 → rewarded, 다시 로드', () async {
    await ads.start();
    expect(await ads.show(AdPlacement.tailwind), AdResult.rewarded);
    await pumpEventQueue();
    expect(sdk.loads, 2);
    expect(ads.ready.value, isTrue);
  });

  test('5. 보상 없이 닫힘 → dismissed, 표시 실패 → failed, 둘 다 다음 로드', () async {
    await ads.start();
    sdk.showOutcome = AdShowOutcome.dismissed;
    expect(await ads.show(AdPlacement.chest), AdResult.dismissed);
    await pumpEventQueue();
    sdk.showOutcome = AdShowOutcome.failed;
    expect(await ads.show(AdPlacement.chest), AdResult.failed);
    await pumpEventQueue();
    expect(sdk.loads, 3);
  });

  test('보여주는 동안엔 준비 아님(중복 표시 방지)', () async {
    await ads.start();
    final c = Completer<AdShowOutcome>();
    final slow = _SlowSdk(c);
    final a = AdMobAds(slow, schedule: (_, _) {});
    await a.start();
    final f = a.show(AdPlacement.chest);
    expect(a.isReady(AdPlacement.chest), isFalse);
    expect(await a.show(AdPlacement.chest), AdResult.notLoaded);
    c.complete(AdShowOutcome.rewarded);
    expect(await f, AdResult.rewarded);
  });

  test('6. 로드 실패 → 30초·60초 … 백오프, 성공하면 초기화', () async {
    sdk.loadResults.addAll([false, false, false, true]);
    await ads.start();
    for (var i = 0; i < 3; i++) {
      await runPending();
    }
    expect(scheduled.map((d) => d.inSeconds).toList(), [30, 60, 120]);
    expect(ads.ready.value, isTrue);
    sdk.loadResults.add(false);
    await ads.show(AdPlacement.chest);
    await pumpEventQueue();
    expect(scheduled.last, const Duration(seconds: 30));
  });

  test('연속 실패 상한: 6번 연속 실패하면 이번 실행에선 더 시도하지 않는다(실패한 로드가 WebView 메모리를 남기는 것 방지)', () async {
    sdk.loadResults.addAll(List.filled(10, false));
    await ads.start();
    for (var i = 0; i < 8; i++) {
      await runPending();
    }
    expect(scheduled.map((d) => d.inSeconds).toList(), [30, 60, 120, 240, 480]);
    expect(sdk.loads, AdMobAds.maxConsecutiveFailures);
    expect(ads.ready.value, isFalse);
  });

  test('7. SDK 초기화 예외는 밖으로 안 나가고 준비 안 됨', () async {
    sdk.initThrows = true;
    await ads.start();
    expect(ads.isReady(AdPlacement.chest), isFalse);
    expect(await ads.show(AdPlacement.chest), AdResult.notLoaded);
  });

  test('8. 광고 단위 ID는 Google 공식 테스트 ID', () {
    expect(AdUnitIds.androidRewarded, 'ca-app-pub-3940256099942544/5224354917');
    expect(AdUnitIds.iosRewarded, 'ca-app-pub-3940256099942544/1712485313');
  });

  test('NoAds는 언제나 준비 안 됨', () async {
    const n = NoAds();
    expect(n.isReady(AdPlacement.chest), isFalse);
    expect(await n.show(AdPlacement.chest), AdResult.notLoaded);
  });

  test('광고가 화면을 덮는 동안 훅: 보여 주기 직전 onShowStart, 끝나면(실패여도) onShowEnd', () async {
    final calls = <String>[];
    final s = FakeAdsSdk()..loadResults.addAll([true, true]);
    final a = AdMobAds(
      s,
      schedule: (_, _) {},
      onShowStart: () => calls.add('start'),
      onShowEnd: () => calls.add('end'),
    );
    await a.start();
    expect(await a.show(AdPlacement.chest), AdResult.rewarded);
    expect(calls, ['start', 'end']);
    s.showOutcome = AdShowOutcome.failed;
    await a.start();
    await a.show(AdPlacement.chest);
    expect(calls, ['start', 'end', 'start', 'end']);
  });

  test('광고가 준비 안 됐으면 훅을 부르지 않는다', () async {
    final calls = <String>[];
    final a = AdMobAds(FakeAdsSdk(), schedule: (_, _) {}, onShowStart: () => calls.add('start'));
    expect(await a.show(AdPlacement.chest), AdResult.notLoaded);
    expect(calls, isEmpty);
  });
}

class _SlowSdk extends FakeAdsSdk {
  _SlowSdk(this.c);

  final Completer<AdShowOutcome> c;

  @override
  Future<AdShowOutcome> show() => c.future;
}
