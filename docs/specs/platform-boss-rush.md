# 설계 메모: 보스 러시 — 장면 모드 재사용 (콘텐츠 v2 2순위)

- 상태: **설계 메모** (2026-10-18, S5) · 근거: `platform-content-v2.md` 2절 B(사용자 확정 순서: 탑 → 러시 → 요일 던전).
- 재료: 탑에서 만든 장면 모드 공통부(`battle/topdown/scene_mode.dart` — prepare·resolve·retreat), 보스 42종·패턴·특성·브레이크·크기 배율, 현상금 보스 소환(`startBoss` bossDef·maxHp).

## 1. 놀이
보스 5마리를 쉬지 않고 연달아 잡는다. 사이 무리 없음. 걸린 시간이 기록이고, 주마다 조합이 바뀐다. 커진 대보스·연속 브레이크·처치 컷인이 5번 터지는 쇼케이스.

## 2. 규칙(초안 — 수치는 S2)
| 항목 | 내용 |
| --- | --- |
| 열림 | 탑과 같게(환생 1 또는 스테이지 60) — 같은 조건 함수 재사용 |
| 조합 | 주(월요일 0시 현지) 번호로 결정론 선택: 해역 보스 2 + 대보스 1 + 순환 보스 2, 순서 = 작은 것 → 대보스 마지막. 그 주 내내 같음(UI가 미리 보여 줌) |
| 보스 세기 | 기준 스테이지 = max(1, floor(최고 스테이지 × stageRatio)), 보스 HP = 그 스테이지 보스 HP × rushHpMultiplier(보스마다 같은 배율), 골드 없음 |
| 진행 | 한 마리가 죽으면 다음 보스가 위쪽에서 바로 나온다(컷인 짧게). 배 체력은 이어진다(회복 없음 — 침몰하면 끝) |
| 기록 | 5마리 처치까지 틱 수. 주간 최고 기록만 남는다 |
| 보상 | 주간 기록 구간(예: 5분 안·3분 안·2분 안)마다 한 번씩 — 젬·지도 조각. 실패해도 잡은 수 × perBoss 젬 |
| 도전 | 주 7회(쌓임, 주가 바뀌면 7로 — 남은 것은 버림이 아니라 그 주 안에 아무 때나). 광고 +1(하루 1) |
| 소탕 | 없음(기록 콘텐츠) — 대신 실패 보상이 있어 손해 없음 |

## 3. 엔진(탑과 같은 틀)
- 세이브 선택 키 `rush: RushState?` — `week`(yyyy-Www), `tickets`, `bestTicks`, `claimed`(받은 기록 구간 인덱스), `active {index, ticks}`.
- 명령 `StartRush` · `RetreatRush`(scene_mode의 sceneRetreat에 한 줄) · 광고 `rushTicket`.
- 이벤트 `RushStarted(bosses[])` · `RushBossDown(index, ticks)` · `RushEnded(killed, ticks, reason, gems, pieces)`.
- BattleView `rush {index, total, ticks}` — HUD '보스 3/5 · 1:42'.
- 전투 `top_rush.dart`: prepare(첫 보스 소환, 끊긴 세이브면 interrupted — 잡은 수만큼 보상), resolve(보스가 죽었으면 다음 소환·RushBossDown, 5마리면 끝, 침몰이면 끝, 틱 +1), retreat. `scene_mode.dart`의 세 함수에 `?? TopRush.…` 한 줄씩.
- 경제 `economy/rush.dart`: 주 바뀜 → 도전 7·조합 다시 뽑기, StartRush(도전 −1·active), 기록·구간 보상.
- 결정론: 조합은 주 번호 + 세이브 rngSeed 해시(같은 주 같은 사람 = 같은 조합, 사람마다 다를 수 있음 — 또는 모두 같게: 사용자 결정 필요 없음, 기본은 '모두 같게'로 랭킹(M6) 대비).

## 4. 시험
조합 결정론(같은 주 같은 5마리) · 5마리 차례 소환·처치 순서 · 침몰 → 잡은 수 보상·본 전투 복귀 · 주간 최고 기록만·구간 보상 한 번 · 도전 쌓임(주 7) · interrupted · JSON 왕복.

## 5. 다른 레인
- S4: 러시 카드(이번 주 보스 5 초상 — HdPortrait), HUD 진행, 결과 창(기록·구간).
- S3: 다음 보스 등장 짧은 컷인(0.6초), 마지막 대보스는 긴 컷인.
- S2: rush 수치(stageRatio·rushHpMultiplier·구간·보상) + 하루 젬 ≤ 140.

## 6. 탑에서 배운 것 반영
- 시험 함대: 신화 함대는 너무 세서 끝나지 않을 수 있다 → 중반 함대(37 샘플 + 환생 1).
- 장면 중엔 본 전투 골드·피버·돌발이 멈춘다(scene_mode — 이미 됨). 보스가 위쪽 출발 원에서 걸어오는 시간(약 3초)이 5번 쌓이니, 러시는 다음 보스를 standoff 원 바로 밖에서 띄운다(빠른 항해 보스처럼).
