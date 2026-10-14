# 계획: platform-m4 (스펙 `docs/specs/platform-m4.md`)

- [x] 0. 레인 시작, main 따라잡기(b306250), 스펙 초안 → S1 보고
- [x] 1. S1 승인 → 요청서 4개(`platform-deps-init`·`platform-notify-setting`·`platform-ui-ports`·`platform-release-check`)
- [x] 2. 테스트 먼저(가짜 SDK): ads 1~8 → 실패 확인 → `adapters/ads/` 구현
- [x] 3. 알림 9~14 → `adapters/notify/` + `parts/platform.*.arb`
- [x] 4. 분석 15~17 → `adapters/analytics/`
- [x] 5. 소리 18~21 → `adapters/audio/`
- [x] 6. android/: 테스트 AdMob 앱 ID·권한(manifest), 조건부 서명·google-services(build.gradle.kts), 빌드 22~23 확인
- [x] 7. docs/store: firebase.md · android-release.md · admob.md
- [ ] 8. check --full → 커밋 → S1에 해시 보고

참고: SDK 패키지가 pubspec에 들어오기 전(S1)에는 SDK 의존 파일(`*_sdk_*.dart`)을 만들 수 없다 → 2~5의 순수 로직·가짜 SDK 테스트를 먼저, SDK 연결 파일은 의존성 머지 뒤.
- [ ] 9. S1 main.dart 연결 뒤 실기기 확인(테스트 광고·UMP·알림·소리) → 계획을 plans/done/으로
