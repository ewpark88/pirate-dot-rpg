# 진척: platform 레인 (S5, worktree pde-platform, 브랜치 lane/platform)

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
