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

  int sfxStops = 0;
  final bgmCalls = <String>[];

  @override
  Future<void> stopAllSfx() async => sfxStops++;

  @override
  Future<void> pauseBgm() async => bgmCalls.add('pause');

  @override
  Future<void> resumeBgm() async => bgmCalls.add('resume');
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

  test('20. 같은 id 동시 4개까지, 하나 끝나면 다시 된다(같은 소리는 60ms 간격)', () async {
    var now = 0;
    final sdk = FakeAudioSdk({'sfx/hit.ogg'});
    final a = await AudioAdapter.load(sdk, nowMs: () => now);
    for (var i = 0; i < 5; i++) {
      a.playSfx('hit');
      now += AudioAdapter.sameSfxGapMs;
    }
    expect(sdk.sfx.length, 4);
    sdk.playing.first.complete();
    await pumpEventQueue();
    a.playSfx('hit');
    expect(sdk.sfx.length, 5);
  });

  test('발열 대책: 같은 소리 60ms 안 반복은 버림, 전체 동시 6개, quiet면 효과음 끔(배경음은 그대로)', () async {
    var now = 0;
    final sdk = FakeAudioSdk({for (var i = 0; i < 8; i++) 'sfx/s$i.ogg', 'bgm/sea.ogg'});
    final a = await AudioAdapter.load(sdk, nowMs: () => now)
      ..playSfx('s0')
      ..playSfx('s0');
    expect(sdk.sfx.length, 1, reason: '같은 소리 간격 안');
    for (var i = 1; i < 8; i++) {
      a.playSfx('s$i');
    }
    expect(sdk.sfx.length, AudioAdapter.maxTotalSfx, reason: '전체 동시 상한');
    for (final c in sdk.playing) {
      c.complete();
    }
    await pumpEventQueue();
    now += 1000;
    a
      ..quiet = true
      ..playSfx('s7')
      ..playBgm('sea');
    expect(sdk.sfx.length, AudioAdapter.maxTotalSfx, reason: 'quiet면 효과음 없음');
    expect(sdk.bgm, ['bgm/sea.ogg']);
    a
      ..quiet = false
      ..playSfx('s7');
    expect(sdk.sfx.length, AudioAdapter.maxTotalSfx + 1);
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
    await Future<void>.delayed(const Duration(milliseconds: AudioAdapter.bgmFadeMs * 2 + 100)); // 페이드 아웃·인
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
  test('목록 읽기가 시간 제한을 넘으면 무음으로 시작한다(첫 프레임을 막지 않음)', () async {
    final a = await AudioAdapter.load(_HangingSdk(), timeout: const Duration(milliseconds: 20));
    expect(a.hasSfx('hit'), isFalse);
  });
  test('광고 동안(suspend): 효과음 끊고 받지 않음, 배경음 일시정지 → unsuspend면 이어서', () async {
    final sdk = FakeAudioSdk({'sfx/hit.ogg', 'bgm/bgm_coral.ogg'});
    final a = await AudioAdapter.load(sdk)
      ..playBgm('bgm_coral')
      ..suspend()
      ..playSfx('hit')
      ..suspend(); // 두 번 불러도 한 번만
    expect(sdk.sfx, isEmpty);
    expect(sdk.sfxStops, 1);
    expect(sdk.bgmCalls, ['pause']);
    a
      ..unsuspend()
      ..playSfx('hit');
    expect(sdk.bgmCalls, ['pause', 'resume']);
    expect(sdk.sfx.single.$1, 'sfx/hit.ogg');
  });

  test('배경음이 안 울리던 중이면 unsuspend가 배경음을 켜지 않는다', () async {
    final sdk = FakeAudioSdk({'sfx/hit.ogg'});
    (await AudioAdapter.load(sdk))
      ..suspend()
      ..unsuspend();
    expect(sdk.bgmCalls, isEmpty);
  });

  test('배경음 바꾸기(피버 전용 곡 #23): 지금 곡을 줄이고 → 새 곡을 0에서 키운다, 도중에 또 바꾸면 앞 페이드는 버린다', () async {
    final sdk = FakeAudioSdk({'bgm/sea.ogg', 'bgm/bgm_fever.ogg'});
    final a = await AudioAdapter.load(sdk)
      ..setVolumes(sfx: 1, bgm: 0.8)
      ..playBgm('sea')
      ..playBgm('bgm_fever');
    expect(sdk.bgm, ['bgm/sea.ogg'], reason: '페이드 아웃 동안은 앞 곡');
    await Future<void>.delayed(const Duration(milliseconds: AudioAdapter.bgmFadeMs + 30));
    expect(sdk.bgm, ['bgm/sea.ogg', 'bgm/bgm_fever.ogg']);
    expect(sdk.bgmVolume, lessThan(0.8), reason: '새 곡은 작게 시작');
    await Future<void>.delayed(const Duration(milliseconds: AudioAdapter.bgmFadeMs + 30));
    expect(sdk.bgmVolume, closeTo(0.8, 1e-9));
    a
      ..playBgm('sea')
      ..playBgm('bgm_fever'); // 같은 곡으로 바로 돌아오면 그대로(이미 울리는 곡)
    await Future<void>.delayed(const Duration(milliseconds: AudioAdapter.bgmFadeMs * 2 + 60));
    expect(sdk.bgm.last, 'bgm/bgm_fever.ogg');
  });
}

class _ThrowingSdk extends FakeAudioSdk {
  _ThrowingSdk() : super({});

  @override
  Future<Set<String>> listAssets() async => throw StateError('manifest');
}

/// 목록 읽기가 끝나지 않는 SDK (같은 프로세스 재실행에서 플랫폼 응답이 안 오는 경우를 흉내).
class _HangingSdk extends FakeAudioSdk {
  _HangingSdk() : super({});

  @override
  Future<Set<String>> listAssets() => Completer<Set<String>>().future;
}
