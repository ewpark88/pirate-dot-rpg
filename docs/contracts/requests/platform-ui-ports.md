# platform → ui: 광고·소리·분석 포트를 받을 provider (S1 중계 → S4)

- 요청 레인 / 날짜: platform(S5) / 2026-10-14 · 스펙 `docs/specs/platform-m4.md` a·c·d
- 바꿀 경로: ui 레인 소유(`apps/game/lib/ui/`). 계약 변경 없음.

## 왜 필요한가
- UI에 `adsReadyProvider`(bool)만 있다 → 버튼을 눌렀을 때 `AdsPort.show`를 부를 통로가 없다.
- `BattleGame(audio:)`를 만드는 `battleGameProvider`(ui)가 audio를 넘기지 않는다 → 소리가 안 난다.
- 이탈 분석 `AnalyticsPort.setLastSeen(screen, stage)`를 부를 자리가 없다.

## 제안 (코드 스케치)
```dart
// ui/state/platform_providers.dart (이름은 ui가 정함)
final adsPortProvider = Provider<AdsPort>((_) => const NoAds());          // NoAds: platform 제공(adapters/ads/no_ads.dart)
final audioPortProvider = Provider<AudioPort?>((_) => null);              // null = 무음
final analyticsPortProvider = Provider<AnalyticsPort>((_) => const NoopAnalytics()); // platform 제공

// 광고 버튼: 결과가 rewarded일 때만 보상 명령
final r = await ref.read(adsPortProvider).show(AdPlacement.chest);
if (r == AdResult.rewarded) sink.send(GrantAdReward(AdPlacement.chest, choice: 'gold'));

// battleGameProvider: BattleGame(..., audio: ref.read(audioPortProvider))
//   + 설정 sfx·bgm listen → audio?.setVolumes(sfx: s.sfx ? 1 : 0, bgm: s.bgm ? 1 : 0)  (숫자 리터럴 규칙은 ui 쪽 상수로)
// 탭 전환·스테이지 변경 → analytics.setLastSeen(screen: '<탭 id>', stage: state.stage)
```
- `NoAds`·`NoopAnalytics`는 platform이 먼저 커밋해서 S1이 머지한 뒤 ui가 import(import 경로 `package:pirate_dot/adapters/...`).
- 설정의 "개인정보 옵션"(UMP 재동의) 버튼은 선택 — 넣으면 `AdMobAds.showPrivacyOptions()`, 보일지 여부는 `privacyOptionsRequired`.

## 그동안 쓰는 임시 어댑터
기본값(NoAds·null·Noop) — 지금 동작과 같다.

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
