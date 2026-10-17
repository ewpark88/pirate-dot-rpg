# platform: 환생 뒤 '출항' 버튼을 눌러야 빠른 항해 시작 — 사용자 피드백 #19 (Progress.sailHold · StartVoyage)

- 요청 레인 / 날짜: platform(S5) / 2026-10-17 · 계획: docs/plans/active/user-feedback-2026-10-17.md · UI: S4
- 바꿀 계약: `state_progress.dart` Progress(선택 키 1), `commands.dart` 명령 1(StartVoyage), 세이브 본문(선택 키라 버전 그대로). 엔진은 `battle/fast_sail.dart`·`battle_system.dart _nextEncounter`·`economy/rebirth.dart`.

## 원인
- `RebirthDialog` 확인 → `Rebirth` 명령 → 다음 전투 틱에 `FastSailRound.breakthrough`가 **조건만 보고 바로** 구간을 연다(`rebirths > 0 && stage ≤ fastSailEnd`).
  엔진에는 '출항 전' 상태가 없다. 그 사이 UI는 `RebirthDoneGate`의 상자 창(RebirthChestDialog)을 띄우고 있어서, 창 뒤에서 돌파가 이미 달리고 있다(사용자가 본 '미리 시작').
- UI가 막을 길도 없다: 전투 일시정지 명령이 없고, `rebirthChestOpenProvider`는 소환 창 순서만 조절한다.

## 제안 (최소)
```dart
// state_progress.dart — 세이브 선택 키(없으면 false = 옛 세이브 그대로, 기본값이면 본문에 안 씀)
final bool sailHold; // 환생 직후 출항 대기: 바다는 잔잔(무리·보스 안 나옴), 빠른 항해 안 열림

// commands.dart
class StartVoyage extends Command { const StartVoyage(); String get type => 'startVoyage'; }
```
- 엔진(S5가 구현, review 브랜치)
  1. `Rebirth` 처리(rebirth.dart): 빠른 항해 범위가 있으면(fastSailEnd != null) `sailHold = true`.
  2. `breakthrough`: `sailHold`면 구간을 열지 않는다. `_nextEncounter`: `sailHold`면 무리·보스를 부르지 않는다(travelLeft 그대로 — 출항 즉시 첫 무리).
  3. `StartVoyage`: `sailHold = false` (+ 이벤트 `VoyageStarted`는 필요 없으면 생략 — FastSailStarted가 바로 따라온다). hold가 아니면 무시.
  4. 오프라인 보상·피버·돌발 이벤트는 hold 중 그대로(전투가 없으니 처치 0).
- UI(S4): 환생 상자 창(RebirthChestDialog)의 닫기 버튼을 **'출항!'**으로 → `StartVoyage`. 앱을 껐다 켜서 `progress.sailHold`가 남아 있으면 전장 위 '출항' 버튼(같은 명령).
- sim(game_cli, S2): 가상 플레이어는 `Rebirth` 직후 `StartVoyage`(지금 결과와 같게). 시나리오·fixtures에 환생이 있으면 같은 처리.
- 결정론: hold 동안 난수를 쓰는 곳 없음. sim은 StartVoyage를 같은 틱에 보내면 지금과 1틱 차이(환생 지표 영향 없음 수준) — 비교표로 확인.

## 그동안 쓰는 임시 어댑터
- 없음(엔진 상태가 필요). 승인 전까지는 S4가 상자 창 문구만 '출항 준비 중' 쪽으로 다듬을 수 있다.

## 처리 결과 (S1 작성)
