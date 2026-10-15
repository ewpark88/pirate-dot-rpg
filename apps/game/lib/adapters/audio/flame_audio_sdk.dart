import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:pirate_dot/adapters/audio/audio_sdk.dart';

/// 실제 재생 (flame_audio, 접두어 `assets/audio/`).
class FlameAudioSdk implements AudioSdk {
  static const _prefix = 'assets/audio/';

  /// 효과음이 끝났다는 신호를 못 받아도 동시 재생 칸이 영원히 막히지 않게.
  static const _sfxTimeout = Duration(seconds: 10);

  @override
  Future<Set<String>> listAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return {
      for (final a in manifest.listAssets())
        if (a.startsWith(_prefix)) a.substring(_prefix.length),
    };
  }

  @override
  Future<void> playSfx(String path, {required double volume, required double rate}) async {
    final player = await FlameAudio.play(path, volume: volume);
    if (rate != 1) await player.setPlaybackRate(rate);
    try {
      await player.onPlayerComplete.first.timeout(_sfxTimeout);
    } on TimeoutException {
      // 끝 신호가 안 와도 동시 재생 칸을 돌려준다 (onTimeout 콜백은 AudioEvent를 돌려줘야 해 타입 오류가 났다 — 2026-10-15 실기기 로그).
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
}
