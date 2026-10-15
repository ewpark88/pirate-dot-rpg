# platform → ui(operator): 운영자 패널에 광고·알림 시험 진입점 (S1 중계 → S4)

- 요청 레인 / 날짜: platform(S5) / 2026-10-15 · 스펙 `docs/specs/platform-m4.md` a·b
- 바꿀 경로: ui 레인 소유(`apps/game/lib/operator/`, `parts/op.*.arb`) + main.dart override 1줄(S1). 계약 변경 없음.

## 왜 필요한가
- 실기기 확인(계획 9단계)에서 광고는 일일 한도·쿨타임, 알림은 8시간·하루 1회 때문에 바로 볼 수 없다.
- 배포 빌드에 남으면 안 되므로 운영자 패널(`if (kOperator)`) 안에만 둔다 → release_check 표식 검사 대상과 같은 트리.

## 제안 (코드 스케치)
```dart
// main.dart (S1): 이미 만든 어댑터를 provider로 노출 (운영자 빌드 아니어도 override해도 무해)
final notifierProvider = Provider<OfflineFullNotifier?>((_) => null);   // 위치는 ui가 정함(ui/state/…)
//   overrides: notifierProvider.overrideWithValue(notifier)

// operator/platform_group.dart (ui) — 패널에 그룹 하나
// 1) "광고 준비: 예/아니오" — ref.watch(adsReadyProvider)
// 2) "보상형 광고 보기" — final r = await ref.read(adsPortProvider).show(AdPlacement.chest);
//      결과(rewarded·dismissed·failed·notLoaded)를 SnackBar로. **보상 명령(GrantAdReward)은 보내지 않는다** — 한도·세이브를 건드리지 않게.
// 3) "개인정보 옵션" — (ads as AdMobAds?)?.showPrivacyOptions()  (privacyOptionsRequired와 무관하게 운영자는 항상 보이기)
// 4) "알림 10초 뒤" — ref.read(notifierProvider)?.testRing()
//      → 권한 묻고 10초 뒤 시험 알림 1건 (id 2, 하루 1회 기록·설정과 무관). 앱을 백그라운드로 보내서 확인.
```
- `OfflineFullNotifier.testRing`·`testId`는 platform 브랜치에 있음(테스트 포함). 머지 뒤 import.
- 문구 키(`op.*`)는 ui가 정함. 하드코딩 금지 규칙대로 ARB.

## 그동안 쓰는 임시 어댑터
없음 — 진입점이 없으면 실기기에서 광고는 실제 상자 버튼, 알림은 8시간 대기로만 본다.

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
