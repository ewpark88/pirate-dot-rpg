# Android 내부 테스트 빌드 (사람 할 일 포함)

스펙: `docs/specs/platform-m4.md` e. iOS는 M6(Codemagic, ADR-0006).

## 1. 업로드 키 만들기 (한 번 — 잃어버리면 복구가 번거롭다)
```bat
keytool -genkey -v -keystore %USERPROFILE%\keys\pirate-dot-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- 저장소 **밖**에 둔다. 비밀번호와 함께 비밀번호 관리자·백업 두 곳에 보관.
- Play Console에서 **Play 앱 서명**을 켠다(기본값) — 이 키는 업로드 키라 잃어버려도 재설정 요청이 가능하다.

## 2. `apps/game/android/key.properties` (커밋 안 함 — `.gitignore`)
```properties
storePassword=<비밀번호>
keyPassword=<비밀번호>
keyAlias=upload
storeFile=C:/Users/<사용자>/keys/pirate-dot-upload.jks
```
없으면 release 빌드가 debug 키로 서명된다(Gradle 경고 출력, 스토어 업로드 불가).

## 3. 버전 올리기
`apps/game/pubspec.yaml`의 `version: 0.1.0+1` — `+` 뒤 빌드 번호를 **업로드마다 +1** (Play가 같은 번호를 거절한다).
pubspec은 shared라 S1에게 요청하거나 S1이 직접.

## 4. 빌드
```bat
cd apps\game
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```
- `--dart-define=OPERATOR=true`를 **넣지 않는다**(운영자 모드 제외).
- 산출물: `apps/game/build/app/outputs/bundle/release/app-release.aab` (2026-10-14 기준 약 52MB, 키 없이 빌드 성공 확인).
- `build/symbols`는 Crashlytics 기호 업로드에 쓴다(`docs/store/firebase.md` 3.4). 업로드마다 보관.
- Windows에서 Kotlin "Could not close incremental caches" 오류 → `android/gradle.properties`의 `kotlin.incremental=false`로 해결돼 있다.

## 5. 운영자 코드 잔존 검사 (업로드 전)
`tool\check.bat --release`(S1이 추가 예정, 요청서 `platform-release-check.md`)가 생기기 전까지 수동:
```bash
cd apps/game
unzip -p build/app/outputs/bundle/release/app-release.aab base/lib/arm64-v8a/libapp.so | grep -c "__OPERATOR_PANEL__"   # 0이어야 함
```
(표식 상수 `__OPERATOR_PANEL__`도 같은 요청서로 operator/에 들어간다. 들어가기 전엔 이 검사가 의미 없다.)

## 6. Play Console 내부 테스트
1. 앱 만들기(이름·기본 언어 ko·게임·무료) → 테스트 → 내부 테스트 → 새 버전 → aab 업로드.
2. 테스터 이메일 목록 → 링크 공유. 첫 업로드는 검토에 몇 시간~며칠.
3. 필수 양식(콘텐츠 등급·대상 연령·데이터 보안·광고 포함 "예")은 M5 문서에서 — 내부 테스트만이면 일부 생략 가능.
