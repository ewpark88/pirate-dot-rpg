# Firebase 설정 (사람 할 일) — Analytics + Crashlytics

설정 파일이 없어도 앱은 빌드되고 돈다(분석·충돌 보고만 꺼짐). 아래를 하면 켜진다. 스펙: `docs/specs/platform-m4.md` c.

## 1. 프로젝트 만들기 (한 번)
1. https://console.firebase.google.com → 프로젝트 추가 (이름 예: pirate-dot). Google Analytics **사용** → 계정 선택(없으면 새로).
2. 프로젝트 설정 → 앱 추가 → **Android**:
   - 패키지 이름: `repo.dot.pirate` (ADR-0002 — M5 전에 바뀌면 Firebase 앱도 새로 등록해야 한다)
   - 디버그 서명 SHA-1: 선택(지금 기능엔 불필요)
3. `google-services.json` 내려받기.

## 2. 파일 넣기
- `apps/game/android/app/google-services.json` 에 둔다. **커밋하지 않는다**(`.gitignore`에 있음 — `git status`에 안 보여야 정상).
- 이 파일이 있으면 Gradle이 google-services·crashlytics 플러그인을 자동 적용한다(`android/app/build.gradle.kts`).
- iOS(`GoogleService-Info.plist`)는 M6.

## 3. 확인
1. `cd apps/game && flutter run --release` (Crashlytics·Analytics 수집은 **배포 빌드에서만**, 운영자 빌드 제외)
2. Analytics: 콘솔 → Analytics → DebugView. 디버그 확인은 `adb shell setprop debug.firebase.analytics.app repo.dot.pirate` 후 앱 실행.
   - 수집은 **UMP 동의 뒤에만** 켜진다(동의 전엔 `firebase_analytics_collection_enabled=false`). EU 밖 기기는 동의 창 없이 바로 켜진다.
3. Crashlytics: 콘솔 → Crashlytics → "앱 실행 대기 중"이 사라지면 연결됨. 시험 충돌은 운영자 메뉴에 없음 — 필요하면 요청.
4. 난독화 빌드의 스택 추적: `--split-debug-info=build/symbols`로 만든 기호를 올린다
   `firebase crashlytics:symbols:upload --app=<Firebase 앱 ID> build/symbols` (Firebase CLI 필요).

## 4. 개인정보처리방침에 넣을 항목 (M5, `docs/store/`)
- 수집: 앱 사용 이벤트·마지막 화면·스테이지(Analytics), 충돌 기록·기기 정보(Crashlytics), 광고 식별자(AdMob).
- 목적: 이탈 분석·버그 수정·광고. 제3자: Google. 동의 철회: 설정 → 개인정보 옵션(UMP, EU).
