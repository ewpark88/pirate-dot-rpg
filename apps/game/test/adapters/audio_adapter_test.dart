import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/audio/audio_adapter.dart';
import 'package:pirate_dot/adapters/audio/audio_sdk.dart';

class FakeAudioSdk implements AudioSdk {
  FakeAudioSdk(this.files);

  final Set<String> files;
  final sfx = <(String, double, double)>[];
  final bgm = <String>[];
  final playing = <Completer<void>>[];
  double? bgmVolume;
  bool bgmStopped = false;

  @override
  Future<Set<String>> listAssets() async => files;

  @override
  Future<void> playSfx(String path, {required double volume, required double rate}) {
    sfx.add((path, volume, rate));
    final c = Completer<void>();
    playing.add(c);
    return c.future;
  }

  @override
  Future<void> playBgm(String path, {required double volume}) async => bgm.add(path);

  @override
  Future<void> setBgmVolume(double volume) async => bgmVolume = volume;

  @override
  Future<void> stopBgm() async => bgmStopped = true;

  @override
  Future<void> pauseBgm() async {}

  @override
  Future<void> resumeBgm() async {}
}

void main() {
  test('18. 변형 파일이 있으면 그것, 없으면 기본 파일 · pitch는 재생 속도', () async {
    final sdk = FakeAudioSdk({'sfx/hit.ogg', 'sfx/hit_1.ogg'});
    final a = await AudioAdapter.load(sdk)
      ..playSfx('hit', variant: 1, pitch: 1.2)
      ..playSfx('hit', variant: 5);
    expect(sdk.sfx.map((e) => e.$1), ['sfx/hit_1.ogg', 'sfx/hit.ogg']);
    expect(sdk.sfx.first.$3, 1.2);
    expect(a.hasSfx('hit'), isTrue);
  });

  test('19. 없는 id·빈 목록·목록 실패는 무음', () async {
    final sdk = FakeAudioSdk({});
    (await AudioAdapter.load(sdk))
      ..playSfx('hit')
      ..playBgm('sea1');
    expect(sdk.sfx, isEmpty);
    expect(sdk.bgm, isEmpty);
    final broken = await AudioAdapter.load(_ThrowingSdk());
    expect(() => broken.playSfx('hit'), returnsNormally);
  });

  test('20. 같은 id 동시 4개까지, 하나 끝나면 다시 된다', () async {
    final sdk = FakeAudioSdk({'sfx/hit.ogg'});
    final a = await AudioAdapter.load(sdk);
    for (var i = 0; i < 5; i++) {
      a.playSfx('hit');
    }
    expect(sdk.sfx.length, 4);
    sdk.playing.first.complete();
    await pumpEventQueue();
    a.playSfx('hit');
    expect(sdk.sfx.length, 5);
  });

  test('21. 효과음 볼륨 0이면 재생 안 함, 같은 배경음은 한 번만', () async {
    final sdk = FakeAudioSdk({'sfx/hit.ogg', 'bgm/sea1.ogg', 'bgm/sea2.ogg'});
    final a = await AudioAdapter.load(sdk)
      ..setVolumes(sfx: 0, bgm: 1)
      ..playSfx('hit')
      ..playBgm('sea1')
      ..playBgm('sea1');
    expect(sdk.sfx, isEmpty);
    expect(sdk.bgm, ['bgm/sea1.ogg']);
    a.playBgm('sea2');
    expect(sdk.bgm, ['bgm/sea1.ogg', 'bgm/sea2.ogg']);
    a.setVolumes(sfx: 1, bgm: 0.5);
    await pumpEventQueue();
    expect(sdk.bgmVolume, 0.5);
  });

  test('배경음 볼륨 0에서 고른 곡은 켜질 때 시작', () async {
    final sdk = FakeAudioSdk({'bgm/sea1.ogg'});
    final a = await AudioAdapter.load(sdk)
      ..setVolumes(sfx: 1, bgm: 0)
      ..playBgm('sea1');
    expect(sdk.bgm, isEmpty);
    a.setVolumes(sfx: 1, bgm: 1);
    expect(sdk.bgm, ['bgm/sea1.ogg']);
    a.stopBgm();
    await pumpEventQueue();
    expect(sdk.bgmStopped, isTrue);
  });
}

class _ThrowingSdk extends FakeAudioSdk {
  _ThrowingSdk() : super({});

  @override
  Future<Set<String>> listAssets() async => throw StateError('manifest');
}
