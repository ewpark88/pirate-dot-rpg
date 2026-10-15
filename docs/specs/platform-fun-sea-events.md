# 기획: 항해 돌발 이벤트 — 1~2분마다 바다에서 무슨 일이 생긴다

- 상태: 초안 (2026-10-15, S5, 사용자 결정 '지루함 해소 3종' ①) · 함께: `platform-fun-fever.md` · `platform-fun-atmosphere.md`
- 한 줄: 전투가 1~2분마다 작은 사건으로 끊긴다 — 황금 물고기 떼, 보물 상선, 바다 괴물 기습, 표류 유리병, 폭풍. **안 눌러도 손해 없음**(방치형), 누르면 더 좋음.
- 피로 규칙(설계서 4.9) 대응:
  - 팝업 없음 — 모두 **전장 안**(말풍선·띠)에서 일어나고 사라진다.
  - 놓쳐도 잃는 것 없음 — 누르지 않으면 기본 보상 또는 그냥 지나감. 실패 벌칙 없음.
  - 하루 할 일 아님 — 횟수·연속 기록·카운트다운 없음.
  - 설정 '돌발 이벤트 끄기' 없음(보상이 있으니) 대신 **절전 모드면 연출만 줄인다**.

## 1. 규칙
1. 엔진이 무리(파)가 끝날 때마다 다음 이벤트까지 남은 시간을 본다. 간격은 `sea_events.intervalSec`(60~120초, rngSeed로 결정). 보스전·현상금 전투 중에는 미룬다.
2. 이벤트 고르기: `events[].weight` 가중 추첨(결정론). 같은 이벤트 연속 2번 금지. `minStage` 미만이면 제외.
3. 이벤트는 **엔진 이벤트**로 시작·끝난다(`SeaEventStarted/Ended`). 렌더가 연출, UI는 전장 위 작은 띠만.
4. 오프라인 동안에는 일어나지 않는다(오프라인 보상 계산 그대로).

## 2. 이벤트 5종 (초기값 — economy가 sim으로 조정)
| id | 무엇 | 지속 | 누르면 | 안 누르면 | 보상 기준 |
| --- | --- | --- | --- | --- | --- |
| `goldfish` | 황금 물고기 떼가 화면을 가로지름(8~12마리) | 6초 | 한 마리 탭마다 골드(그 스테이지 처치 골드 × `perFish` 3) | 배가 자동으로 30% 잡음 | 처치 골드 배수 |
| `merchant` | 보물 상선이 지나감 — 무리에 섞인 큰 적(체력 = 일반 × 6) | 20초 | (탭 불필요) 잡으면 젬 `gems` 3 + 보유 선원 카드 1 | 20초 지나면 떠남 | 고정 |
| `ambush` | 바다 괴물 기습 — 미니보스 1(체력 = 스테이지 보스 × 0.4), 화면 흔들·경고 띠 | 25초 | (탭 불필요) 잡으면 골드 = 보스 골드 × 0.5, 함성 게이지 +30% | 25초 지나면 물러남(실패 아님, 스테이지 그대로) | 보스 골드 배수 |
| `bottle` | 표류 유리병이 떠옴 | 10초 | 탭 → 쪽지 3장 중 고르기(골드 꾸러미 / 순풍 10분 / 선물 1) | 10초 뒤 첫 번째(골드)를 자동으로 | 선택 |
| `storm` | 폭풍이 지나감(분위기 기획의 비·번개와 같이) | 45초 | (탭 불필요) 적 이동 속도 ×1.3, 처치 골드 ×1.5 | 그대로 | 배수 |

- 확률(가중치 초기값): goldfish 30 · merchant 20 · ambush 20 · bottle 20 · storm 10.
- 현상금·피버와 겹치면: 피버 중이면 이벤트를 피버 끝으로 미룬다(연출 겹침 방지).

## 3. 테이블 — `packages/game_data/tables/sea_events.json` (economy)
```json
{
  "intervalSec": [60, 120], "minStage": 5, "noRepeat": true,
  "events": [
    {"id": "goldfish", "weight": 30, "durationSec": 6,  "count": [8, 12], "perFish": 3, "autoCatchRatio": 0.3},
    {"id": "merchant", "weight": 20, "durationSec": 20, "hpMultiplier": 6, "gems": 3, "cards": 1},
    {"id": "ambush",   "weight": 20, "durationSec": 25, "bossHpRatio": 0.4, "goldBossRatio": 0.5, "rage": 0.3},
    {"id": "bottle",   "weight": 20, "durationSec": 10, "choices": [{"type": "gold", "minutesOfKills": 3}, {"type": "tailwind", "sec": 600}, {"type": "gift", "count": 1}]},
    {"id": "storm",    "weight": 10, "durationSec": 45, "enemySpeed": 1.3, "goldMultiplier": 1.5}
  ]
}
```
- `bottle`의 `gift`는 선원 호감 기획(`platform-content-crew-bond.md`) 전까지 젬 5로 대체.
- 하루 젬 상한(콘텐츠 개요의 ≤140)에 merchant 젬을 포함해 sim(1시간 ≈ 6~8건 × 20% × 3젬 ≈ 4젬/시간).

## 4. 계약 (S1 리뷰)
- 세이브: `seaEvents: {nextAtTick: int, last: "goldfish"}` (선택 키, 없으면 지금부터 60초). 진행 중인 이벤트는 저장하지 않는다(다시 열면 사라짐 — 손해 아님).
- 명령: `TapSeaEvent(targetId)`(황금 물고기 한 마리) · `PickBottle(index)`.
- 이벤트: `SeaEventStarted(id, untilTick)` · `SeaEventEnded(id, result)` · `GoldfishCaught(targetId, gold)` · `BottleOpened(choices)` · `BottlePicked(index, reward)`.
- 적: merchant·ambush는 기존 `EnemyView`에 `eventKind` 필드(렌더가 그림 고르기) — 새 적 종류 `merchant_ship`·`sea_serpent`.

## 5. UI · 렌더
- ui: 전장 위 왼쪽 위 작은 띠(아이콘 + '보물 상선!' + 남은 막대) — 탭 막지 않음. 유리병 쪽지 3장은 **전장 안 말풍선**(전장 아래 패널 덮지 않음, 10초 막대).
- render/art:
  - 황금 물고기(16px 4프레임) · 보물 상선(배 스프라이트 크기, 돛에 금화) · 바다 괴물(보스 크기, 등장 물보라) · 유리병(8px 흔들림) · 폭풍(분위기 기획의 비·번개 재사용).
  - 탭 판정: 물고기·병은 화면 좌표 → 엔진 id (기존 보물상자 탭과 같은 방식).
- **태블릿(800×1280)**: 전장이 폭을 채우므로 물고기 떼는 게임 영역(320×180) 안에서만 — 늘어난 바다 띠로 나가면 사라진 것으로 친다.

## 6. 수용 기준
1. Given 같은 rngSeed When 10분 시뮬 두 번 Then 이벤트 순서·시각 같음, 같은 이벤트 연속 없음, 간격 60~120초.
2. Given 보스전 중 When 이벤트 시각 도달 Then 보스전 끝난 뒤 시작.
3. Given goldfish 10마리 When 3마리 탭 Then 탭 3마리 골드 + 남은 7마리 중 30%(2마리, 내림) 자동.
4. Given merchant 20초 동안 못 잡음 When 끝 Then 떠남, 보상 0, 스테이지·파 그대로.
5. Given bottle When 10초 동안 안 고름 Then 첫 쪽지(골드) 자동 지급.
6. Given 오프라인 2시간 When 복귀 Then 오프라인 보상만, 이벤트 보상 없음.
7. Given 절전 모드 When 이벤트 Then 보상 같음, 연출만 간소(파티클 수 ½).
8. sim: 1시간 방치 시 이벤트 보상이 처치 골드의 +10~20% 안(economy 기준값).

## 7. 레인 분담
| 레인 | 할 일 |
| --- | --- |
| battle | 이벤트 시계·추첨(결정론), merchant·ambush 적 스폰·퇴장, storm 배수, goldfish 자동 30% |
| economy | `sea_events.json`, 보상 계산·지급, 유리병 선택, sim |
| render/art | 물고기·상선·괴물·병 그림·연출, 탭 판정 좌표, 폭풍(분위기 기획과 공유) |
| ui | 전장 위 띠, 유리병 말풍선(전장 안) |
| S1 | 계약(명령 2·이벤트 5·`EnemyView.eventKind`·세이브 선택 키) |
