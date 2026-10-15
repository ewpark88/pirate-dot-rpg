# 진척: platform 레인 (S5, worktree pde-platform, 브랜치 lane/platform)

## 2026-10-15 · S5 · main(세이브 v4 알림 설정) 머지, Built-in Kotlin 경고 조사
- 한 일: main 7551e04 머지(Settings.notifications·main.dart enabled/onSettingChanged 연결 확인). Gradle 경고 조사 → `docs/store/android-release.md` 7절.
- 발견: 경고 원인은 템플릿의 `android.builtInKotlin=false`(firebase 최신판은 이미 대응, 플래그 때문에 KGP 적용). `true`로 바꾸면 `audioplayers_android` 5.3.0(최신)이
  옛 buildscript·junit5 플러그인 때문에 실패 → 되돌림. 지금은 할 일 없음, audioplayers 대응판이 나오면 다시.
- 다음 할 일: 실기기 결과 대기.

## 2026-10-15 · S5 · S1 main.dart 연결 머지 뒤 빌드 확인, 실기기 확인 절 초안
- 한 일: main(어댑터 연결 3e1efd6 포함) 머지 → `check --full` 통과(156.5초). `flutter build apk --profile` 성공(80.1MB), 운영자(`OPERATOR=true`) profile 성공(111.2MB).
  `release_check` 재실행: 표식 `__OPERATOR_PANEL__` 배포 aab 0회 · 운영자 apk 1회 → 통과(aab 54.4MB).
  `docs/plans/active/platform-device-test.md` = DEVICE_TEST.md "3. 플랫폼 확인" 절 초안(9항목, S1이 붙임). human-inputs.md: 아이콘 그림을 art(S3) 담당으로 옮김.
- 발견: Gradle이 일부 플러그인이 "Built-in Kotlin"을 지원하지 않는다고 경고(빌드는 성공). 앞으로 Flutter/AGP 올릴 때 막힐 수 있음 — 그때 플러그인 버전 확인.
  효과음 파일이 아직 없어 실기기에서 무음이 정상.
- 다음 할 일: 실기기 결과 대기. S2 meta-notify·S4 operator-test/save-failure 반영 뒤 main.dart TODO 교체 확인.

## 2026-10-15 · S5 · PC 재시작 뒤 재개: main 머지, 아이콘 적용 스크립트, 요청서 2개, 사람 입력 목록
- 한 일: main 머지(fast-forward, 25커밋) → `check --full` 통과(137.5초). S1에 main.dart 연결 권장안 전송(초기화 순서·no-op·kOperator·save 체인).
  `apps/game/android/icon/apply_icons.py`(+테스트 10개, Pillow): 원본 격자 PNG → 밀도별 최근접 정수 배율 mipmap, 적응형 XML, colors, 스플래시(11 이하 layer-list filter=false, 12+ values(-night)-v31), 스토어 512px.
  격자 크기·필수 파일·단색 2색이면 아무것도 안 쓰고 실패, 안전 원 밖은 경고. `OfflineFullNotifier.testRing()`(운영자용, id 2, 하루 기록·설정 무관, 테스트 1개).
  요청서 `platform-operator-test`(ui: 운영자 패널 광고 보기·개인정보 옵션·알림 10초 뒤), `platform-save-failure`(ui: diskFull·io 띠).
  런처 이름 `@string/app_name` — values `Pirate Dot`(영문 확정 전) / values-ko `해적도트 원정대`. `docs/store/human-inputs.md`(사람 입력 모아 보기).
- 다음 할 일: S1 main.dart 연결 → 실기기 확인(human-inputs.md 마지막 절). 아이콘 그림이 오면 apply_icons.py.
- 남은 문제: 계정·키·결정 대기 목록은 human-inputs.md.

## 2026-10-14 · S5 · 사용자 입력 반영(이름·개발자·연락처·웹사이트), Blogger app-ads.txt 조사
- 한 일: 게임 이름 해적도트 원정대(확정)·영문 Pirate Dot Expedition(확정 대기)·개발자 박은우·repo.dev88@gmail.com·웹사이트 rich-fire.blogspot.com을
  listing.ko/en·privacy-policy.ko/en·admob.md에 반영. Analytics 보존 기간은 '미정' 유지. app-ads.md를 Blogger 기준으로 새로 씀.
- 확인(curl): `/app-ads.txt` → 301 → `/ads.txt`(200, text/plain, 이미 `pub-8353634332299342` 한 줄), 없는 경로 404, robots.txt가 크롤러를 막지 않음.
- 확인 필요(단정 안 함): AdMob이 경로가 바뀌는 리다이렉트를 인정하는지(공식 문서에 없음 — AdMob 콘솔에서만 판정), 기존 pub ID가 AdMob 게시자 ID와 같은지,
  영문 개발자명 표기. 안 되면 대안: Firebase Hosting `<프로젝트>.web.app` 또는 GitHub 사용자 사이트를 Play 웹사이트로.
- 다음 할 일: S1 main.dart 연결·실기기 확인, M5에 AdMob 콘솔 app-ads.txt 판정.

## 2026-10-14 · S5 · 저장 견고화, 알림 문구 최종, 아이콘·스플래시 규격
- 한 일: 스펙 `platform-save`(S1 지시) → 테스트 먼저 7개 → `FileSaveStore`: write는 던지지 않음(실패는 `failure` = diskFull|io),
  일시 실패 3번 시도(50·200ms), 디스크 가득(28·112·39)은 재시도 없이 tmp 삭제, 백업 2단(bak→bak2), readBackup이 bak 깨지면 bak2(코어 loadSave 무변경).
  알림 문구 최종(설계서 4.9 톤, 재촉 없음) + 시간 `{hours}` = meta.offline.maxSec에서 계산. `docs/store/icon.md`(도트 정수 배율 격자 54·24·64px, 적응형·단색·스플래시 12+/11 이하, 적용 순서).
- 발견: `EngineHost.save()`의 `_saving.then(write)` 체인은 write가 한 번 던지면 이후 저장이 전부 건너뛰어진다 → 어댑터가 안 던지게 막음, S1에 catchError 이중 장치 권함.
  minSdk = Flutter 기본 24(Android 7.0) → 예전 아이콘(48dp)도 필요.
- 다음 할 일: S1 main.dart 연결·실기기 확인, 아이콘 그림이 오면 icon.md 4절 순서로 적용, `failure` 표시(ui 결정).
- 남은 문제: 루트 .gitignore에 `save.bak2` 없음(S1) — 테스트는 임시 폴더라 영향 없음.

## 2026-10-14 · S5 · 배포 검사 스크립트, 스토어 문구·개인정보처리방침 초안
- 한 일: S1이 0860520 머지(2497b11) → main 머지. `release-check` 요청서에 표식 상수·`tool/release_check.dart` 전문(의존성 없는 zip 리더) 추가.
  실제 빌드로 확인: `--marker op.invincible` → 배포 aab 0회 · 운영자 apk 1회(2분 41초) = 지금 배포 빌드에 운영자 패널 없음.
  docs/store: listing.ko/en(앱 이름·간단한 설명 80자·자세한 설명·스크린샷 8장 목록·그래픽 규격), privacy-policy.ko/en(+Play 데이터 보안 양식 대응표), app-ads.md.
  영어 문구의 배 등급·해역·콤보 이름은 게임 ARB(en)와 맞춤(Sloop·Pirate Warship·Phantom Sea 등).
- 발견: 개인정보처리방침이 "설정 > 개인정보 옵션"(UMP 재동의)을 약속한다 → ui-ports 요청의 이 버튼은 '선택'이 아니라 EU 출시 전 필수.
  app-ads.txt는 도메인 루트여야 해서 GitHub **프로젝트** Pages로는 안 된다(사용자 사이트나 커스텀 도메인).
- 다음 할 일: S1 main.dart 연결 뒤 실기기 확인. 사람 입력 대기: 연락 이메일·개발자명·게임 이름 확정·Analytics 보존 기간.
- 남은 문제: 스토어 문구는 게임 이름 확정(ADR-0002) 전 임시. 스크린샷은 사람이 캡처.

## 2026-10-14 · S5 · M4 어댑터 4개 + Android 빌드 설정
- 한 일: 스펙 승인(S1) → 요청서 4개(9bd27da) → AdMob 테스트 앱 ID 급히 분리 커밋(6f40e02) → main 2번 머지(deps 7개 포함).
  테스트 먼저(가짜 SDK, 26개 — 수용 기준 1~21 전부) → 구현: `adapters/ads/`(AdMobAds·NoAds·GoogleAdsSdk·테스트 ID),
  `adapters/notify/`(OfflineFullNotifier·notify.json 기록·LocalNotificationsSdk·문구 `parts/platform.*.arb`),
  `adapters/analytics/`(startAnalytics·SdkAnalytics·NoopAnalytics·firebase_sdk), `adapters/audio/`(AudioAdapter·FlameAudioSdk).
  android/: 예약 알림 수신기·부팅 권한, Firebase 수집 기본 꺼짐, desugaring, google-services·crashlytics 플러그인은 `google-services.json` 있을 때만, key.properties 릴리스 서명.
  docs/store: firebase.md · android-release.md · admob.md.
- 검증: `check --full` 통과(62.8초). `flutter build apk --debug` 성공(수용 23), `flutter build appbundle --release --obfuscate`가 키 없이 성공(수용 22, 51.8MB).
- 발견: Windows에서 Kotlin "Could not close incremental caches"(프로젝트 D:, pub 캐시 C:) → `android/gradle.properties`에 `kotlin.incremental=false`.
  `MetaTable`에 `notifications.dailyMax`가 파싱되지 않음 → notify-setting 요청서에 추가. 하드코딩 문구 검사가 debugPrint의 한글도 잡음 → 로그는 영어.
  lane 소유권 검사는 `main...HEAD` 기준이라, S1이 내 커밋을 머지한 뒤엔 main을 다시 머지해야 merge-base가 맞는다.
- 다음 할 일: S1 main.dart 연결(어댑터 머지 때) → 실기기에서 테스트 광고·알림 확인, ui의 adsPortProvider·audioPortProvider 반영 확인,
  release-check 표식이 들어오면 수동 검사 실행. 그다음 스토어 문구 ko/en·개인정보처리방침·app-ads.txt(레인 할 일 6).
- 남은 문제: SDK 연결 파일(google_ads_sdk·local_notifications_sdk·firebase_sdk·flame_audio_sdk)은 단위 테스트 없음 — 실기기 확인 필요.
  운영자 모드 진입점(광고·알림 테스트)은 operator 소유 레인 몫(선택). iOS는 M6까지 no-op.

## 2026-10-14 · S5 · 레인 시작, M4 스펙 초안
- 한 일: main fast-forward(b306250). `docs/specs/platform-m4.md` 초안(광고 AdMob+UMP·로컬 알림·Analytics/Crashlytics·flame_audio·Android 내부 테스트 빌드, 수용 기준 23개),
  계획 `docs/plans/active/platform-m4.md`. 패키지 최신 버전 pub.dev에서 확인(2주 미만 버전은 피함).
- 발견: 설정에 알림 키 없음 → 계약 요청 필요(세이브 v4). UI에 AdsPort·AudioPort를 받을 provider 없음(`adsReadyProvider`만) → ui 레인 요청.
- 다음 할 일: S1 승인 → 요청서 → 테스트 먼저 → 구현.
- 남은 문제: SDK 의존성(S1 pubspec) 머지 전엔 SDK 연결 파일을 못 만든다.
