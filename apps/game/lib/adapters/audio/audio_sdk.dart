/// flame_audio를 감싼 얇은 경계. 경로는 `assets/audio/` 기준(`sfx/hit.ogg`). 실제 구현은 `flame_audio_sdk.dart`.
abstract interface class AudioSdk {
  /// `assets/audio/` 아래 번들된 파일 목록(상대 경로).
  Future<Set<String>> listAssets();

  /// 재생을 시작하면 끝난다(완료를 기다리지 않는다 — 플레이어는 SDK가 돌려 쓴다).
  Future<void> playSfx(String path, {required double volume, required double rate});

  /// 울리고 있는 효과음을 모두 끊는다(광고 표시 직전).
  Future<void> stopAllSfx();

  /// 반복 재생. 앞의 곡은 멈춘다.
  Future<void> playBgm(String path, {required double volume});

  Future<void> setBgmVolume(double volume);

  Future<void> stopBgm();

  Future<void> pauseBgm();

  Future<void> resumeBgm();

  /// 배경음 재생 속도(1 = 원래). 플랫폼이 못 하면 예외 — 어댑터가 삼킨다.
  Future<void> setBgmRate(double rate);

  /// 환경음 층 반복 재생(배경음과 따로 — 앞의 환경음은 멈춘다).
  Future<void> playAmbient(String path, {required double volume});

  Future<void> setAmbientVolume(double volume);

  Future<void> stopAmbient();

  Future<void> pauseAmbient();

  Future<void> resumeAmbient();
}
