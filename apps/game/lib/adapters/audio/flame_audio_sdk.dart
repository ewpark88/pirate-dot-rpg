import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:pirate_dot/adapters/audio/audio_sdk.dart';

/// 실제 재생 (flame_audio가 다시 내보내는 audioplayers, 접두어 `assets/audio/`).
///
/// 효과음은 **경로마다 플레이어 [voices]개를 돌려 쓴다**(낮은 지연 모드). FlameAudio.play는 부를 때마다 새 플레이어를 만들고
/// 버리지 않아, 전투 중 초당 수십 개가 쌓여 CPU·메모리가 치솟았다(2026-10-15 실기기: CPU 278%, PSS 1.09GB, 광고 뒤 더 심함).
/// 효과음은 오디오 포커스를 잡지 않고 다른 소리와 섞는다 — 효과음마다 포커스를 다투지 않게.
class FlameAudioSdk implements AudioSdk {
  FlameAudioSdk({this.voices = 4});

  /// 같은 효과음을 동시에 낼 수 있는 수(= 경로당 플레이어 수). 넘치면 가장 오래된 것을 끊고 다시 쓴다.
  final int voices;

  static const _prefix = 'assets/audio/';
  static final AudioContext _sfxContext = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  final _pools = <String, _SfxPool>{};

  @override
  Future<Set<String>> listAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return {
      for (final a in manifest.listAssets())
        if (a.startsWith(_prefix)) a.substring(_prefix.length),
    };
  }

  @override
  Future<void> playSfx(String path, {required double volume, required double rate}) =>
      _pools.putIfAbsent(path, () => _SfxPool(path, voices, _sfxContext)).play(volume, rate);

  @override
  Future<void> stopAllSfx() async {
    for (final p in _pools.values) {
      await p.stopAll();
    }
  }

  @override
  Future<void> playBgm(String path, {required double volume}) => FlameAudio.bgm.play(path, volume: volume);

  @override
  Future<void> setBgmVolume(double volume) => FlameAudio.bgm.audioPlayer.setVolume(volume);

  @override
  Future<void> stopBgm() => FlameAudio.bgm.stop();

  @override
  Future<void> pauseBgm() => FlameAudio.bgm.pause();

  @override
  Future<void> resumeBgm() => FlameAudio.bgm.resume();

  @override
  Future<void> setBgmRate(double rate) => FlameAudio.bgm.audioPlayer.setPlaybackRate(rate);

  AudioPlayer? _ambient;

  @override
  Future<void> playAmbient(String path, {required double volume}) async {
    await _ambient?.dispose();
    final p = _ambient = AudioPlayer()..audioCache = FlameAudio.audioCache;
    await p.setAudioContext(_sfxContext); // 배경음 포커스를 빼앗지 않게 섞는다
    await p.setReleaseMode(ReleaseMode.loop);
    await p.play(AssetSource(path), volume: volume);
  }

  @override
  Future<void> setAmbientVolume(double volume) async => _ambient?.setVolume(volume);

  @override
  Future<void> stopAmbient() async {
    final p = _ambient;
    _ambient = null;
    await p?.dispose();
  }

  @override
  Future<void> pauseAmbient() async => _ambient?.pause();

  @override
  Future<void> resumeAmbient() async => _ambient?.resume();
}

/// 한 효과음 파일의 플레이어 고리. 처음 쓸 때 하나씩 만들고(소스를 미리 실어 둠), 다 차면 가장 오래된 것부터 돌려 쓴다.
class _SfxPool {
  _SfxPool(this.path, this.size, this.context);

  final String path;
  final int size;
  final AudioContext context;
  final _players = <AudioPlayer>[];
  int _next = 0;

  Future<AudioPlayer> _player() async {
    if (_players.length < size) {
      final p = AudioPlayer()..audioCache = FlameAudio.audioCache;
      _players.add(p); // 먼저 넣어 같은 프레임의 다른 요청이 플레이어를 더 만들지 않게
      try {
        await p.setAudioContext(context);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource(path));
      } on Object {
        _players.remove(p); // 만들다 실패한 플레이어를 고리에 남기지 않는다
        unawaited(p.dispose().catchError((Object _) {}));
        rethrow;
      }
      return p;
    }
    final p = _players[_next];
    _next = (_next + 1) % size;
    await p.stop();
    return p;
  }

  Future<void> play(double volume, double rate) async {
    final p = await _player();
    try {
      await p.setVolume(volume);
      if (rate != 1) await p.setPlaybackRate(rate);
      await p.resume();
    } on Object {
      // 고장 난 플레이어(소스 해제·플랫폼 오류)는 고리에서 빼서 다음에 새로 만든다 — 그 자리만 계속 무음이 되지 않게.
      _players.remove(p);
      if (_next >= _players.length) _next = 0;
      unawaited(p.dispose().catchError((Object _) {}));
      rethrow;
    }
  }

  Future<void> stopAll() async {
    for (final p in _players) {
      await p.stop();
    }
  }
}
