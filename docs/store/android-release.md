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
`tool/release_check.dart`(S1이 옮길 예정 — 코드는 요청서 `platform-release-check.md`):
```bat
dart run tool/release_check.dart                  :: aab + 운영자 apk 둘 다 빌드해서 검사 (약 2분 40초)
dart run tool/release_check.dart --marker op.invincible   :: 표식 상수가 들어오기 전
```
배포 aab의 `libapp.so`에 표식이 0회, 운영자 apk에 1회 이상이어야 통과. 2026-10-14 `op.invincible`로 확인: 배포 0회 · 운영자 1회.
**주의**: 검사가 운영자 apk를 마지막에 만들므로, 업로드용 aab는 검사 **뒤에** 4번 명령으로 다시 만들 필요는 없다(aab와 apk는 출력 경로가 다르다).

## 6. Play Console 내부 테스트
1. 앱 만들기(이름·기본 언어 ko·게임·무료) → 테스트 → 내부 테스트 → 새 버전 → aab 업로드.
2. 테스터 이메일 목록 → 링크 공유. 첫 업로드는 검토에 몇 시간~며칠.
3. 필수 양식(콘텐츠 등급·대상 연령·데이터 보안·광고 포함 "예")은 M5 문서에서 — 내부 테스트만이면 일부 생략 가능.

## 7. Gradle "Built-in Kotlin" 경고 (2026-10-15 조사, S5)
빌드마다 `WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): firebase_analytics, firebase_core, firebase_crashlytics`
+ "Future versions of Flutter will fail to build if your app uses plugins that apply KGP". **지금 빌드는 성공한다**(debug·profile·release 모두).

- 환경: Flutter 3.44.0, AGP 9.0.1, Gradle 9.1.0, KGP 2.3.20. `android/gradle.properties`에 Flutter 템플릿이 넣은 `android.builtInKotlin=false`·`android.newDsl=false`(옵트아웃).
- **원인은 firebase가 아니라 옵트아웃 플래그.** firebase 3개는 최신판(core 4.15.0·analytics 12.6.0·crashlytics 5.4.0, 2026-09-14)이고 이미 Built-in Kotlin을 지원한다:
  `if (agpMajor < 9 || !builtInKotlin) apply plugin: 'kotlin-android'` — 우리가 `builtInKotlin=false`라서 KGP를 쓰는 것. 업그레이드할 버전이 따로 없다.
  다른 직접 의존성(google_mobile_ads 9.1.0·flutter_local_notifications 22.3.1·path_provider)은 KGP를 쓰지 않는다.
- **실험: `android.builtInKotlin=true`로 바꾸면 빌드 실패** — 막는 것은 `audioplayers_android` 5.3.0(flame_audio 2.12.2 → audioplayers 6.8.1 경유, pub.dev 최신, 2026-06-22):
  옛 `buildscript`(AGP 7.3.1·KGP 1.7.10 classpath) + `apply plugin: 'de.mannodermaus.android-junit5'`(27행) → `Failed to apply plugin 'com.android.internal.library'`,
  "KGP was not found on the classpath". → 플래그를 false로 되돌림(지금 상태).
- 업그레이드 경로 (Flutter가 KGP 지원을 실제로 끊기 전까지는 할 일 없음):
  1. audioplayers_android가 AGP 9/Built-in Kotlin 대응판을 내면(changelog 확인) → `flutter pub upgrade audioplayers` → `builtInKotlin=true` 다시 시도.
  2. 그때 앱 쪽 마이그레이션: `settings.gradle.kts`의 `org.jetbrains.kotlin.android` 줄 삭제, `newDsl=true` 시도(앱 `build.gradle.kts`는 이미 kts·`kotlin { compilerOptions }`),
     `kotlin.incremental=false`(Windows 드라이브 문제)가 여전히 필요한지 확인. 안내: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin
  3. 대응판이 없는데 Flutter를 올려야 하면: flame_audio 대신 다른 오디오 플러그인(예: just_audio·soloud — 그때 Built-in Kotlin 지원 여부 확인)으로 `FlameAudioSdk`만 교체
     (`AudioSdk` 포트 뒤라 adapters/audio 한 파일). 또는 Flutter 업그레이드 보류.
- 확인 필요: audioplayers 저장소에 AGP 9 이슈·대응 계획이 있는지(검색으로는 못 찾음). 같은 문제는 wakelock_plus #117·file_picker #1942 등 여러 플러그인에 보고돼 있다.
