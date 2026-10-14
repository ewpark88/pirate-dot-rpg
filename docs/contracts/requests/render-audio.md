# 계약 변경 요청: render-audio (render → S1)

- 요청: S3 render · 2026-10-14 · 관련 스펙: `docs/specs/render-audio.md`
- 상태: 제안 (S1 결정 대기)

## E. 포트 `AudioPort` (game_core `ports.dart`, contracts에서 export)
```dart
/// 효과음·배경음. 렌더가 이벤트를 보고 부르고, 어댑터(apps/game/lib/adapters/)가 실제로 재생한다.
abstract interface class AudioPort {
  /// [id]는 fx_map.json의 sfx id(예: `hit`, `hit_crit`, `boss_horn`). [variant]는 같은 소리의 몇 번째 변형(0부터),
  /// [pitch]는 재생 속도 배율(1 = 원래). 볼륨 0이면 아무것도 하지 않는다.
  void playSfx(String id, {int variant = 0, double pitch = 1});

  /// [id]는 regions.json의 bgm id. 같은 곡이면 이어서 재생, 다른 곡이면 바꾼다.
  void playBgm(String id);
  void stopBgm();

  /// 설정 화면 값 0~1 (0 = 끔). UI가 설정을 바꿀 때 부른다.
  set sfxVolume(double v);
  set bgmVolume(double v);
}
```
- 테스트용 `SilentAudio`(부른 기록만 남김)를 `testing.dart`(fakes)에 추가.

## 이유
- 렌더는 `ui/`·`adapters/`를 import할 수 없다(check). 재생 구현(플랫폼 레인)과 호출하는 쪽(렌더)이 만나는 자리가 계약에 있어야 한다.
- 코어는 소리를 몰라도 된다 — 포트만 계약에 두고 엔진은 쓰지 않는다(다른 포트와 달리 `GameEngine`에 주입하지 않음).

## 호환
- 새 인터페이스 추가뿐. 세이브·기록 형식 변화 없음.
