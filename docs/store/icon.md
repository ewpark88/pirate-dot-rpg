# 앱 아이콘·스플래시 — 규격과 적용 절차

- 상태: 2026-10-14, S5. 그림은 사람/아트(render 레인이 `assets/`·`tools/art/` 소유), `android/` 적용은 platform.
- 지금(2026-10-15): S3 원본 `tools/art/icon/`(6장 전부)을 `apply_icons.py --bg "#5AA9E6" --splash-bg "#5AA9E6"`로 적용. 스토어 512px는 `build/store/icon-512.png`(커밋 안 함, 다시 굽기).
  실기기 확인(원형·사각·테마 아이콘·스플래시 12+/11 이하)은 DEVICE_TEST 3절과 함께.

## 핵심: 도트 그림은 정수 배율로만 키운다
보통의 아이콘 생성기(flutter_launcher_icons 등)는 부드럽게 리샘플해서 도트가 뭉갠다. 그래서 **밀도별 PNG를 정수 배율(최근접)로 미리 만들어** 넣는다.
아래 격자 크기를 쓰면 모든 밀도가 정수 배율이 된다.

| 무엇 | 원본 격자(px) | mdpi | hdpi | xhdpi | xxhdpi | xxxhdpi |
| --- | --- | --- | --- | --- | --- | --- |
| 적응형 아이콘 전경·배경·단색 (108dp) | **54×54** | 108 (×2) | 162 (×3) | 216 (×4) | 324 (×6) | 432 (×8) |
| 예전 아이콘 (48dp, Android 7.x) | **24×24** | 48 (×2) | 72 (×3) | 96 (×4) | 144 (×6) | 192 (×8) |
| 스토어 아이콘 512×512 | **64×64** | — | — | — | — | 512 (×8) |
| 스플래시 로고 (Android 11 이하) | **48×48** 권장 | 96 (×2) | 144 (×3) | 192 (×4) | 288 (×6) | 384 (×8) |

## 1. 적응형 아이콘 (Android 8+, 대부분의 기기)
- 캔버스 108dp(= 54px 격자) 중 **가운데 지름 66dp(= 33px 원) 안**에 중요한 그림. 바깥 18dp는 기기마다 잘린다(원·사각·물방울).
- 레이어 3장:
  - `ic_launcher_foreground.png` — 배·해골 깃발 등 주인공. 투명 배경.
  - `ic_launcher_background.png` — 바다·하늘 패턴, 또는 단색이면 PNG 대신 색 하나(`@color/ic_launcher_background`).
  - `ic_launcher_monochrome.png` — Android 13 "테마 아이콘"용. 전경과 같은 모양, 한 가지 색 + 투명.
- 넣을 곳: `apps/game/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/` (위 표 크기)
- 추가할 파일 `res/mipmap-anydpi-v26/ic_launcher.xml`:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
      <background android:drawable="@mipmap/ic_launcher_background" />
      <foreground android:drawable="@mipmap/ic_launcher_foreground" />
      <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
  </adaptive-icon>
  ```
- 예전 아이콘 `ic_launcher.png`(24px 격자)도 같은 폴더에 교체 — Android 7.x(minSdk가 24일 때)용.

## 2. 스플래시
- **Android 12+**: 시스템 스플래시가 자동으로 **런처 아이콘 전경**을 가운데 보여 준다(별도 그림 불필요). 배경색만 정한다:
  `res/values-v31/styles.xml`의 `LaunchTheme`에
  ```xml
  <item name="android:windowSplashScreenBackground">@color/splash_background</item>
  ```
  (다크 모드는 `values-night-v31/`에 같은 항목.)
- **Android 11 이하**: `drawable/launch_background.xml`·`drawable-v21/launch_background.xml`을
  ```xml
  <layer-list xmlns:android="http://schemas.android.com/apk/res/android">
      <item android:drawable="@color/splash_background" />
      <item>
          <bitmap android:gravity="center" android:src="@drawable/splash_logo" android:filter="false" />
      </item>
  </layer-list>
  ```
  `android:filter="false"` = 최근접 확대(도트가 안 흐려진다). `splash_logo.png`는 `drawable-{mdpi..xxxhdpi}/`에 위 표 크기.
- `res/values/colors.xml`: `splash_background`, `ic_launcher_background` — 게임 첫 화면(바다) 색과 같게 하면 스플래시→게임 전환이 깜빡이지 않는다.
- 스플래시는 Flutter 첫 프레임까지(보통 1초 안). 로딩 화면 대용이 아니다.

## 3. 스토어용
- 앱 아이콘 512×512 PNG(32비트, 1MB 이하) — 64px 격자 ×8. 적응형 아이콘과 같은 그림, 모서리는 Play가 둥글게 깎는다(직접 깎지 않는다).
- 그래픽 이미지 1024×500 — `listing.ko.md` 참고. 도트라면 256×125 격자 ×4.

## 4. 그림을 받으면 (작업 순서)
1. 아트가 원본 격자 PNG를 `apps/game/assets/` 밖 작업 폴더(예: `tools/art/icon/`, render 레인)에 둔다 — 앱에 번들하지 않는 원본.
2. 원본 이름을 `foreground.png`(54)·`legacy.png`(24) + 선택 `background.png`(54)·`monochrome.png`(54)·`splash.png`(48)·`store.png`(64)로 맞춘다.
3. platform이 `apps/game/android/icon/apply_icons.py`로 한 번에 넣는다(최근접 정수 배율 PNG, `anydpi-v26`·`colors.xml`·`launch_background.xml`·`values(-night)-v31/styles.xml`, 스토어 512px는 `build/store/`):
   ```
   python -I apps/game/android/icon/apply_icons.py --src <원본 폴더> --bg "#RRGGBB" [--splash-bg "#RRGGBB"] --dry-run   # 검사만
   python -I apps/game/android/icon/apply_icons.py --src <원본 폴더> --bg "#RRGGBB" [--splash-bg "#RRGGBB"]
   ```
   격자 크기가 틀리면·필수 파일이 없으면·단색 아이콘이 2색이면 아무것도 쓰지 않고 실패한다. 안전 원 밖 픽셀은 경고만. 테스트: `python -I -B -m unittest discover -s apps/game/android/icon`.
   그다음 `flutter build apk --debug` → 실기기에서
   원형·사각 런처, 다크 모드, Android 13 테마 아이콘, 스플래시(12+와 11 이하 각각) 확인.
4. 라이선스: 직접 그린 그림이면 `assets/LICENSES.json`에 OWN(앱에 번들하는 원본이 있을 때만 — res/ 아래 아이콘은 검사 대상 밖).

## 5. 앱 이름 (런처 아래 글자)
manifest `android:label="@string/app_name"` — `res/values/strings.xml`(기본 = 영문, 지금 임시 `Pirate Dot`) +
`res/values-ko/strings.xml`(`해적도트 원정대`, 2026-10-14 확정). 영문 이름이 확정되면 `values/strings.xml`만 바꾼다.
