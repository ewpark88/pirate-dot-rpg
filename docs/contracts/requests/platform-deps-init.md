# platform: SDK 의존성 + main.dart 초기화·override

- 요청 레인 / 날짜: platform(S5) / 2026-10-14 · 스펙 `docs/specs/platform-m4.md`(S1 승인)
- 바꿀 공유 경로: `apps/game/pubspec.yaml`, `apps/game/lib/main.dart` (계약 `contracts.dart` 변경 없음)

## 왜 필요한가
광고·알림·분석·소리 어댑터가 SDK를 불러야 한다. pubspec·main.dart는 shared(S1).

## 제안

### 1. pubspec `dependencies` (2주 이상 지난 버전 — 최신이 2일 전인 두 개는 한 단계 아래로 고정)
```yaml
  firebase_analytics: ^12.6.0
  firebase_core: ^4.15.0
  firebase_crashlytics: ^5.4.0
  flame_audio: ^2.12.2
  flutter_local_notifications: 22.3.1
  google_mobile_ads: ^9.1.0
  timezone: 0.11.1
```
Flutter 3.44 / Dart ^3.12와 호환(flame_audio ≥3.41, google_mobile_ads·notifications ≥3.38).
Android 쪽(desugaring·조건부 google-services 플러그인·AdMob 앱 ID·권한)은 platform이 `android/`에서 한다.

### 2. main.dart (어댑터 이름은 platform 구현 기준 — 머지 때 맞춰 보낸다)
```dart
// runApp 전 — 어느 것도 앱 시작을 막지 않는다(실패 = no-op).
final analytics = await FirebaseAnalyticsAdapter.tryStart(collect: !kOperator && kReleaseMode); // 설정 파일 없으면 NoopAnalytics
final audio = await FlameAudioAdapter.load();                        // assets/audio 없으면 무음
final ads = AdMobAds(GoogleAdsSdk());                                 // 동의(UMP) → 로드는 뒤에서
final notifier = OfflineFullNotifier(
  sdk: LocalNotificationsSdk(), clock: clock, tables: tables,
  dir: await getApplicationSupportDirectory(),
  enabled: () => host.state.settings.notifications,                   // platform-notify-setting 반영 전엔 () => true
  lang: () => host.state.settings.lang,
);

// overrides에 추가
adsReadyProvider.overrideWith((ref) {
  void bump() => ref.invalidateSelf();
  ads.ready.addListener(bump);
  ref.onDispose(() => ads.ready.removeListener(bump));
  return ads.ready.value;
}),
adsPortProvider.overrideWithValue(ads),       // platform-ui-ports 반영 후
audioPortProvider.overrideWithValue(audio),   // platform-ui-ports 반영 후
analyticsPortProvider.overrideWithValue(analytics),

// runApp 뒤
unawaited(ads.start());                                   // UMP 폼은 첫 프레임 뒤에 떠야 한다
// 기존 AppLifecycleListener에 합친다
AppLifecycleListener(
  onPause: () async { await host.pause(); await notifier.onPause(); audio.pauseBgm(); },
  onResume: () { host.resume(); unawaited(notifier.onResume()); audio.resumeBgm(); },
);
```
- EU Analytics 수집은 UMP 동의에 묶는다(S1 결정 ②): `ads.consent`가 바뀌면 `analytics.setCollection(granted)` — 연결 한 줄, 머지 때 정확한 이름을 보낸다.

### 3. 루트 `.gitignore`
`apps/game/android/app/google-services.json`, `apps/game/ios/Runner/GoogleService-Info.plist`, `apps/game/android/key.properties`, `*.jks`
(android/ 하위는 platform이 `android/.gitignore`에도 넣는다 — 루트는 이중 안전장치.)

## 그동안 쓰는 임시 어댑터
SDK 호출 없는 순수 로직 + 가짜 SDK 테스트로 진행. SDK 연결 파일(`*_sdk.dart`)은 이 요청 머지 뒤.

## 처리 결과 (S1 작성)
- [x] 수정 반영(2026-10-14, S1): pubspec 7개는 `flutter pub add`로 **정확한 버전 고정**(^ 없음), 루트 .gitignore 4줄. main.dart 초기화·override는 platform 어댑터 머지 때 S1이 넣는다.
