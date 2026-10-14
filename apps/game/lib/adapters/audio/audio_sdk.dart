/// flame_audio를 감싼 얇은 경계. 경로는 `assets/audio/` 기준(`sfx/hit.ogg`). 실제 구현은 `flame_audio_sdk.dart`.
abstract interface class AudioSdk {
  /// `assets/audio/` 아래 번들된 파일 목록(상대 경로).
  Future<Set<String>> listAssets();

  /// 다 재생되면 끝난다.
  Future<void> playSfx(String path, {required double volume, required double rate});

  /// 반복 재생. 앞의 곡은 멈춘다.
  Future<void> playBgm(String path, {required double volume});

  Future<void> setBgmVolume(double volume);

  Future<void> stopBgm();

  Future<void> pauseBgm();

  Future<void> resumeBgm();
}
