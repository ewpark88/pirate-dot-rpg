# ui → S2(경제): 업적 — 표 `achievements` · 진행 값 · `ClaimAchievement`

- 요청 레인 / 날짜: ui(S4) / 2026-10-18 · 근거: S1 지시(업적·칭호 화면 정리, 출시 준비). 구현은 S2 boss-feel 뒤.
- 화면(S4)은 가짜 데이터로 먼저 만든다(`apps/game/lib/ui/meta/achievements.dart` — `AchievementsSource` 임시 어댑터). 계약이 오면 어댑터만 바꾼다.

## 1. 표 `game_data/tables/achievements.json` (안 — 수치는 S2가 BALANCE.md에 맞춰 확정)
업적 하나 = 종류 하나에 단계 여러 개(목표 수가 커지며 젬이 는다). 단계를 다 받으면 그 업적 끝.

| id | 무엇을 센다(진행 값) | 단계 목표(안) | 단계 젬(안) |
| --- | --- | --- | --- |
| kills | 누적 처치 수 | 1K · 10K · 100K · 1M · 10M | 10 · 20 · 40 · 80 · 150 |
| bosses | 누적 보스 처치 | 10 · 50 · 200 · 1K | 10 · 30 · 60 · 120 |
| stage | 최고 스테이지 | 20 · 40 · 80 · 150 · 300 | 10 · 20 · 40 · 80 · 150 |
| rebirths | 환생 횟수 | 1 · 3 · 5 · 10 · 20 | 20 · 40 · 60 · 100 · 200 |
| collection | 도감 선원 수 | 10 · 20 · 30 · 40 | 20 · 40 · 80 · 150 |
| mythic | 신화 선원 수 | 1 · 3 · 5 | 50 · 100 · 200 |
| tower | 탑 최고 층 | 10 · 20 · 30 · 50 | 20 · 40 · 80 · 150 |
| rushClear | 러시 5마리 모두 잡은 횟수 | 1 · 5 · 20 | 20 · 50 · 100 |
| rushFast | 러시 최고 기록(초, 짧을수록) | 300 · 180 · 120 | 30 · 60 · 100 |
| fever | 피버 발동 횟수 | 10 · 100 · 500 | 10 · 30 · 80 |
| ultimate | 필살기 사용 횟수 | 10 · 100 · 1K | 10 · 30 · 80 |
| dungeon | 요일 던전 클리어 단계 합 | 10 · 50 · 200 | 20 · 50 · 100 |
| bounty | 현상금 성공 | 5 · 30 · 100 | 10 · 30 · 80 |
| summons | 누적 소환 수 | 10 · 100 · 500 | 10 · 30 · 80 |
| shipLevel | 배 부위 레벨 합 | 100 · 500 · 2K | 10 · 40 · 100 |

각 항목 키: `{id, nameKey, iconKey, metric, steps:[{target, gems}], lowerIsBetter?}` (`nameKey`는 econ ARB, 이름은 S2).

## 2. 세이브 `GameState.achievements: Map<String, int>` (선택 키, 버전 안 올림)
- 업적 id → **받은 단계 수**. 진행 값은 세이브의 기존 누계에서 계산하고, 없는 누계(처치·보스·피버·필살기·소환·러시 클리어)는 `progress` 누계 키를 새로 둔다.

## 3. 경제 함수(export)
- `achievementsView(GameState s, GameTables t) → List<AchievementView>`: `{id, nameKey, iconKey, value, step, steps, nextTarget?, nextGems?, claimable}` — 화면이 그대로 그린다.
- `achievementsClaimable(s, t) → int` — 빨간 점 수.

## 4. 명령·이벤트
| 이름 | 처리 |
| --- | --- |
| `ClaimAchievement(id)` | 다음 단계 목표에 닿았으면 젬 지급, 받은 단계 +1. 아니면 무시 |
| `AchievementClaimed(id, step, gems)` | 화면 보상 연출·토스트 |

## 5. 화면(S4 — 이미 가짜 데이터로)
항해 탭 칭호 띠 옆 '업적' 버튼 → 시트: 업적마다 아이콘 · 이름 · 단계 별(받은 단계) · 진행 막대(값/다음 목표) · [받기 +n젬](금빛) 또는 '완료'. 받을 것이 있으면 버튼에 빨간 점.

## 처리 결과 (S1 작성)
- [x] 반영 — 구현 S5 0dd77773(main 9d399174), S1 승인 — SystemContext.recent 버퍼 계약 추가 포함
