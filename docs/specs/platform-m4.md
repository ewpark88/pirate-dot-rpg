# 스펙: 플랫폼 M4 — 광고·알림·분석·소리·Android 내부 테스트 빌드

- 상태: 승인됨(2026-10-14, S1 — 사용자 위임). 결정: 알림 권한 = 첫 오프라인 복귀, EU Analytics = UMP 동의에 묶음, iOS = M6까지 no-op · 레인: platform · 설계서 절: 3.2 포트, 4.6 광고, 4.9 이탈 분석, 4.4 소리, 9장 수익화·규정
- 범위: 포트 어댑터 4개(`AdsPort`·알림·`AnalyticsPort`+Crashlytics·`AudioPort`) + Android 릴리스 서명·빌드 절차.
  pubspec 의존성·`main.dart` 연결·`tool/check` 단계는 **S1**(요청서 `docs/contracts/requests/platform-*.md`), 사람 할 일은 `docs/store/*.md`.

## 목적 (설계서 1장)
- 시원한가: 광고·알림·분석이 게임 루프를 막지 않는다. 초기화가 실패하면 **조용히 없는 것처럼** 동작한다(no-op).
- 단순한가: 어댑터는 포트 계약만 구현한다. 규칙(일일 한도·보상량·쿨다운)은 코어(`ads.json`·`meta.json`)가 이미 갖고 있다.
- 피로가 없는가: 알림은 오프라인 보상이 가득 찬 순간 **하루 1번**만, 설정에서 끈다.
- 공정한가: 보상은 SDK 보상 콜백(`AdResult.rewarded`)에서만. 동의 전·로드 전엔 광고 버튼 자체가 없다.

## 공통 원칙
- 모든 SDK는 얇은 인터페이스(`*Sdk`) 뒤에 둔다 → 테스트는 가짜 SDK로, 실제 SDK 호출은 `*_sdk_*.dart` 한 파일씩.
- 실패(설정 파일 없음·네트워크·플러그인 예외)는 잡아서 no-op로 바꾸고 `debugPrint`만 한다. 앱 시작을 막지 않는다.
- 숫자(8시간·하루 1회)는 테이블에서 읽는다: `meta.offline.maxSec`, `meta.notifications.dailyMax`.

## a. AdsPort — AdMob 보상형 + UMP (`adapters/ads/`)
규칙
1. 시작 시 UMP: `requestConsentInfoUpdate` → 필요하면 `loadAndShowConsentFormIfRequired` → `canRequestAds()`가 true일 때만
   `MobileAds.instance.initialize()`와 첫 로드. **동의 전엔 로드하지 않는다**(따라서 `isReady` = false).
2. 광고 단위 ID는 **Google 공식 테스트 ID만**(Android `ca-app-pub-3940256099942544/5224354917`, iOS `.../1712485313`),
   AdMob 앱 ID도 테스트 앱 ID(`ca-app-pub-3940256099942544~3347511713`)를 `AndroidManifest.xml`에. 실제 ID 교체는 M5, 사람(`docs/store/admob.md`).
3. 보상형은 형식이 하나라 **로드된 광고 1개를 모든 장치(placement)가 공유**한다. `isReady(p)` = 로드됨 && 동의됨.
4. `show(p)`: 미로드 → `notLoaded`, 보상 콜백 → `rewarded`, 보상 없이 닫힘 → `dismissed`, 표시 실패 → `failed`.
   닫히면(결과와 무관) 즉시 다음 광고를 로드. 로드 실패는 지수 백오프(30초·60초·…·최대 10분)로 재시도.
5. 어댑터는 일일 한도(`ads.json dailyCap·dailyLimit·firstOfferAfterSec`)를 **세지 않는다** — 코어·UI 몫. 보상 지급은 UI가
   `rewarded`일 때만 `GrantAdReward(p)`를 보낸다.
6. 준비 상태는 `ValueListenable<bool> ready`로 낸다(로드·소비·동의 변화마다 갱신).
7. 설정의 "개인정보 옵션"(UMP privacy options) 진입점: `showPrivacyOptions()` — 버튼은 ui 레인(필요하면 따로 요청).

연결 (main.dart, S1) — `adsReadyProvider`(ui, `tutorial.dart`)는 `Provider<bool>`이라 값이 바뀌면 다시 계산되게 override:
```dart
final ads = await AdMobAds.start();            // 실패해도 NoAds처럼 동작하는 인스턴스
adsReadyProvider.overrideWith((ref) {
  void bump() => ref.invalidateSelf();
  ads.ready.addListener(bump);
  ref.onDispose(() => ads.ready.removeListener(bump));
  return ads.ready.value;
}),
adsPortProvider.overrideWithValue(ads),        // ← ui 레인에 아직 없음: 요청서에 포함
```
- 광고를 실제로 띄우려면 UI가 `AdsPort`를 읽을 통로가 필요하다 → **ui 레인에 `adsPortProvider = Provider<AdsPort>((_) => const NoAds())` 요청**
  (`NoAds`는 platform이 `adapters/ads/no_ads.dart`에 제공: `isReady` false, `show` → `notLoaded`).
- `adsReadyProvider`는 장치 구분이 없다. 장치별로 숨길 일이 생기면(예: 일일 한도) UI가 코어 상태와 AND 한다.

## b. 로컬 알림 — 오프라인 보상 가득 (`adapters/notify/`)
규칙
1. 앱이 백그라운드로 갈 때(`onPause`, 저장 직후) 한 번 예약: 시각 = 지금 + `meta.offline.maxSec`(28800초 = 8시간).
   돌아오면(`onResume`) 예약 취소. 앱 종료도 pause를 거치므로 같은 경로.
2. 하루 최대 `meta.notifications.dailyMax`(1)회: **알림이 울릴 현지 날짜** 기준으로 센다. 그 날짜에 이미 예약·발송한 기록이
   있으면 예약하지 않는다. 기록은 어댑터 전용 파일 `notify.json`(앱 지원 폴더, 세이브와 별개 — 세이브 스키마 무변경).
3. 설정이 꺼져 있으면 예약하지 않고 남은 예약도 취소. **설정 키가 없다** → 계약 요청 `platform-notify-setting.md`
   (`Settings.notifications: bool = true`, 세이브 v4 마이그레이션, 설정 화면 토글은 ui). 그동안은 provider 기본값 true.
4. Android 13+ 권한(`POST_NOTIFICATIONS`): 처음 **오프라인 복귀(60초 이상 비운 뒤 onResume)** 때 한 번만 묻는다. 거절하면 다시 묻지 않는다.
   정확한 알람 권한은 쓰지 않는다(`inexactAllowWhileIdle` — 몇 분 늦어도 괜찮다).
5. 문구는 `parts/platform.{ko,en}.arb`, 언어는 `settings.lang`(system이면 기기 언어). 위젯 밖이라 `lookupAppLocalizations`.
6. 알림을 누르면 앱이 열린다(복귀 팝업은 기존 흐름). 페이로드 없음.

## c. AnalyticsPort + Crashlytics (`adapters/analytics/`)
1. `Firebase.initializeApp()` 실패(= `google-services.json`/`GoogleService-Info.plist` 없음) → `NoopAnalytics`, Crashlytics 미설치.
   Android Gradle의 google-services·crashlytics 플러그인은 **파일이 있을 때만 적용**(build.gradle.kts에서 조건부) → 파일 없이도 빌드된다.
2. `log(event, params)` → `FirebaseAnalytics.logEvent`(이름 40자·영숫자/밑줄 검증, 어기면 debug assert + 무시).
   `setLastSeen(screen, stage)` → 사용자 속성 `last_screen`·`last_stage` + `screen_view`.
3. Crashlytics: `FlutterError.onError`·`PlatformDispatcher.instance.onError` → `recordError`. **디버그·운영자 빌드에선 수집 끔**.
   커스텀 키 `stage`·`screen`(setLastSeen 때 갱신).
4. 누가 `log`를 부르는지(이벤트 목록)는 이 스펙 밖 — 지금은 `setLastSeen`만 연결 요청(ui의 탭 전환 + 스테이지). 이벤트 목록은 후속 스펙.
5. 사람 절차: `docs/store/firebase.md`(프로젝트 생성 → 앱 등록 `repo.dot.pirate` → 파일 위치 → 확인 방법 → 개인정보처리방침 항목).
   설정 파일은 **커밋하지 않는다**(`.gitignore`, 요청서에 포함).

## d. AudioPort — flame_audio (`adapters/audio/`)
1. 파일 규칙: `assets/audio/sfx/<id>.ogg`, 변형은 `<id>_<n>.ogg`(n=0부터), 배경음 `assets/audio/bgm/<id>.ogg`.
2. 시작 시 `AssetManifest`로 있는 파일만 목록화. **없는 id는 무음**(예외 없음). `assets/audio/` 자체가 없으면 전부 무음.
3. `playSfx`: 같은 id 동시 재생 최대 4개(넘으면 버림), `pitch` → 재생 속도. 볼륨 0이면 아예 재생하지 않는다.
4. `playBgm`: 같은 곡이면 그대로, 다르면 교체(루프). `setVolumes`는 즉시 반영. 백그라운드 → bgm 일시정지, 복귀 → 재개.
5. 연결: `BattleGame(audio:)`를 만드는 곳은 ui의 `battleGameProvider` → **ui 레인에 `audioPortProvider`(기본 null) 요청**,
   설정 `sfx`·`bgm` → `setVolumes(1 또는 0)`. 음원 고르기·`LICENSES.json` 등록은 사람/render(art).
   pubspec `assets:`에 `assets/audio/sfx/`·`bgm/`을 넣는 것은 폴더가 생긴 뒤(S1) — 없는 폴더를 적으면 빌드가 깨진다.

## e. Android 내부 테스트 빌드
1. 서명: `android/key.properties`(커밋 안 함)가 있으면 release 서명, 없으면 debug 서명으로 빌드되고 **경고 출력**.
   키 만들기·보관·Play App Signing 등록은 사람 — `docs/store/android-release.md`.
2. 명령(내 문서에 기록):
   `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`
   (`--dart-define=OPERATOR=true`를 넣지 **않는다**). 산출물 `build/app/outputs/bundle/release/app-release.aab` → Play Console 내부 테스트.
3. 운영자 코드 잔존 검사(제안 — `tool/check` 단계는 S1, 요청서 `platform-release-check.md`):
   - 운영자 패널에 고유 표식 문자열 상수(예: `'__OPERATOR_PANEL__'`)를 하나 둔다(operator/ 소유 레인).
   - 검사: aab(zip)를 풀어 `base/lib/arm64-v8a/libapp.so`에서 표식을 바이트 검색 → **있으면 실패**.
   - 양성 대조: 같은 검사를 `--dart-define=OPERATOR=true` 빌드에 돌리면 **있어야 한다**(검사가 실제로 작동하는지).
   - 무거워서(빌드 2~4분) 기본 check가 아니라 `tool\check.bat --release` 같은 별도 단계로.
4. 버전: `pubspec version`의 빌드 번호를 올리는 것은 사람(업로드마다 +1) — 문서에 적는다.

## 수용 기준 (Given / When / Then) — 테스트는 `apps/game/test/adapters/`
광고
1. Given 동의 안 됨(canRequestAds false) When 시작 Then 로드 호출 0회, `isReady` false.
2. Given 동의됨·로드 성공 When `isReady(chest)`·`isReady(offline)` Then 둘 다 true, `ready.value` true.
3. Given 로드 안 됨 When `show` Then `notLoaded`, SDK show 호출 0회.
4. Given 로드됨 When 보상 콜백 후 닫힘 Then `rewarded`, 그 뒤 다시 로드 1회.
5. Given 로드됨 When 보상 없이 닫힘 Then `dismissed`. When 표시 실패 Then `failed`. 둘 다 다음 로드.
6. Given 로드 실패 When 시간 경과 Then 30초 뒤 재시도, 다음 실패는 60초, 상한 10분(가짜 타이머).
7. Given SDK 초기화 예외 When 시작 Then 예외가 밖으로 안 나가고 `isReady` 항상 false.
8. 광고 단위 ID 상수가 Google 테스트 ID와 같다(실수로 실제 ID가 들어오면 실패).
알림
9. Given 설정 켜짐, 오늘 기록 없음 When pause(now) Then now+28800초에 1건 예약.
10. Given 같은 날짜(울릴 날짜 기준)에 이미 예약 기록 When pause Then 예약 0건. 다음 날짜면 예약.
11. Given 예약 있음 When resume Then 취소.
12. Given 설정 꺼짐 When pause Then 예약 0건 + 남은 예약 취소.
13. Given lang=en When 예약 Then 제목·본문이 en ARB 문구.
14. Given 권한 미요청 When 60초 이상 비운 뒤 resume Then 권한 요청 1회. 두 번째 복귀엔 다시 안 묻는다.
분석
15. Given Firebase 초기화 실패 When 시작 Then `NoopAnalytics`, `log` 호출이 예외 없이 무시.
16. Given 정상 When `setLastSeen(screen: 'ship', stage: 12)` Then 사용자 속성 2개 + Crashlytics 키 2개.
17. Given 이벤트 이름 규칙 위반(공백·41자) When `log` Then SDK 호출 없음.
소리
18. Given 매니페스트에 `hit.ogg`·`hit_1.ogg` When `playSfx('hit', variant: 1)` Then `hit_1.ogg` 재생. 없는 `variant: 5` → `hit.ogg`.
19. Given 없는 id When `playSfx` Then 무음·예외 없음. 매니페스트가 비어도 동일.
20. Given 같은 id 4개 재생 중 When 5번째 Then 버림.
21. Given sfx 볼륨 0 When `playSfx` Then 재생 호출 0회. `playBgm` 같은 곡 두 번 → 재생 1회.
빌드(문서·수동)
22. key.properties 없이 `flutter build appbundle --release`가 성공(경고와 함께) — 진척 문서에 결과 기록.
23. Firebase 설정 파일 없이 `flutter build apk --debug` 성공.

## 문구 (ko / en) — `parts/platform.*.arb`
| 키 | ko | en |
| --- | --- | --- |
| `platformNotifyOfflineFullTitle` | 보물창고가 가득 찼어요! | Your treasure hold is full! |
| `platformNotifyOfflineFullBody` | 8시간 동안 모은 전리품이 기다려요. 받으러 오세요. | 8 hours of loot is waiting. Come claim it! |
| `platformNotifyChannelName` | 오프라인 보상 | Offline rewards |

## 운영자 모드에서 불러보는 법 (operator/ 소유 레인에 요청 — 이 스펙 범위 밖, 선택)
- "광고 테스트": 현재 `ready`·동의 상태 표시, `show(chest)` 결과 표시. "알림 테스트": 10초 뒤 알림 1건(일일 한도 무시).
- 그 전엔 테스트 광고 ID라 실기기에서 실제 화면(테스트 광고)으로 확인 가능.

## S1에 보낼 요청서 (승인 후 작성)
- `platform-deps-init.md`: pubspec 의존성 + main.dart 초기화·override 코드 + `.gitignore`(google-services.json, key.properties).
  버전(2주 이상 지난 것): google_mobile_ads ^9.1.0, flutter_local_notifications 22.3.1, timezone 0.11.1,
  firebase_core ^4.15.0, firebase_analytics ^12.6.0, firebase_crashlytics ^5.4.0, flame_audio ^2.12.2.
  주의: flame_audio 2.12는 Flutter ≥3.41, google_mobile_ads 9는 ≥3.38 — 현재 3.44 OK.
- `platform-notify-setting.md`: `Settings.notifications` + 세이브 v4 + 설정 토글(ui).
- `platform-ui-ports.md`(ui 레인 대상, S1 경유): `adsPortProvider`, `audioPortProvider`, 탭 전환 시 `setLastSeen` 호출 자리.
- `platform-release-check.md`: 운영자 표식 상수 + `tool/check --release` 단계.

## 미결 (S1/사람 결정)
- 알림 권한 묻는 시점: 위 4번(첫 오프라인 복귀) 제안. 튜토리얼 끝난 직후도 가능.
- EU 사용자 Analytics 동의: UMP 동의 결과로 `setAnalyticsCollectionEnabled`를 함께 끌지(제안: 끈다 = 보수적).
- iOS(ATT·APNs·Info.plist)는 M6 — 이번엔 코드가 iOS에서 no-op로 안전하게 도는 것까지만.
