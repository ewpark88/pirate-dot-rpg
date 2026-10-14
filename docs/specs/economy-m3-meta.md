# 스펙: economy M3 메타 — 보물상자·일일 퀘스트·출석·광고 보상·순풍·다음 목표·도감·튜토리얼

- 상태: **승인됨** (2026-10-14, S1·사용자 위임, 결정 ①~④ 반영) · 레인: economy · 설계서 절: 4.5 · 4.6 · 4.9 · 4.12 · 요청: `docs/contracts/requests/ui-m3-meta.md` B1~B10
- 계약: 세이브 v3(main 83fa79e, ADR-0008)의 `BattleView.chest`·`DailyState.questsClaimed/attendanceClaimed`·`GameState.tutorialStep`·명령을 쓴다. 이 스펙으로 계약을 더 바꾸지 않는다(‘결정 필요’ 4번 제외).

## 목적
- 시원한가: 상자 탭 한 번에 골드 2분치, 광고 보면 ×5. 순풍 30분 ×2.
- 단순한가: 퀘스트 4개, 출석 7일, 목표 막대는 늘 하나.
- 피로가 없는가: 출석은 빠져도 초기화 없음, 광고는 버튼으로만(팝업 없음), 튜토리얼은 언제든 건너뛰기.
- 공정한가: 광고 한도·보상은 `ads.json`에서만, 하루 총 25회.

## 규칙
1. **보물상자** (B2·B3, 설계서 4.6) — `EconomySystem.update`가 매 틱 처리.
   - 첫 상자는 플레이 `ads.firstOfferAfterSec` 뒤, 이후 `chest.intervalSec`마다. 튜토리얼 중(`tutorialStep != null`)에는 띄우지 않는다.
   - 상자는 하루 한도 없이 주기마다 뜬다. `placements.chest.dailyLimit`(10)는 광고 보상 횟수 한도다(`ads.json` 정의).
   - 띄우면 `battle.chest = ChestView(x, y, ticksLeft = floatSec ÷ tick)` + `ChestSpawned`. 매 틱 `ticksLeft − 1`, 0이면 가라앉음(chest = null).
   - 위치: x는 `ads.chest.xMin~xMax`(새 키, 필드 비율) 사이 난수, y는 `waves.field.laneY.surface`.
   - `TapChest`: 상자가 있으면 `chestReward` 골드 지급 + `ChestOpened` + 상자 제거. 없으면 무시.
   - `chestReward(state, tables) = 초당 골드 추정(오프라인과 같은 식, 효율 계수 없음) × chest.baseGoldSec`.
2. **광고 보상** `GrantAdReward(placement)` (B4) — 광고 포트가 보상 콜백을 준 뒤에만 들어온다.
   - 장치 한도 `placements[].dailyLimit`와 하루 총 `ads.dailyCap`(25)을 넘으면 무시. 통과하면 `daily.ads[id]` +1, 퀘스트 `ad` +1.
   - chest: 떠 있는 상자가 있어야 한다. `choice: 'gems'`면 젬 `altGems`(30), 아니면 골드 `chestReward × value(5)`. 상자 제거 + `ChestOpened`(결정 ①).
   - tailwind: `tailwindUntil = max(now, tailwindUntil) + durationSec`, 단 `now + maxStackSec`을 넘지 않는다.
   - offline: `lastOfflineGold`가 있을 때만 — 그만큼 한 번 더(×2) 주고 지운다. `ClaimOffline`이 `lastOfflineGold`를 채운다(결정 ④).
   - freeSummon: 젬 없이 `Summon(1)`과 같은 규칙(천장·summonsTotal 포함).
   - bossSupport: 전투 버프라 전투 레인이 적용 — 경제는 한도·횟수만 센다.
3. **순풍** (B5) `Duration tailwindRemaining(state, now)` = `tailwindUntil − now`, 0 미만은 zero. 효과(골드·전투 속도 ×2) 적용은 전투 레인.
   `OpGrantTailwind(d)`는 광고와 같은 누적 규칙(한도 무시).
4. **일일 초기화** — `update`에서 `localDate(clock.now()) != daily.date`면 `DailyState(date: 오늘, attendanceDay: 유지, attendanceClaimed: false)`로.
5. **일일 퀘스트** (B6·B7, `meta.dailyQuests`)
   - 진행: upgrade(강화 1레벨마다), summon(소환 1장마다), ad(광고 보상 1회마다)는 경제가 센다. kill은 전투만 알므로 **전투가 `addQuestProgress(state, tables, 'kill', n)`을 부른다**(S1 수용).
   - `dailyQuests(state, tables) → List<QuestView{id, type, progress, target, done}>`, `canClaimDaily` = 4개 모두 done이고 아직 안 받음.
   - `ClaimDaily`: 끝났고 아직 안 받은 퀘스트마다 `dailyQuestRewardGems`(10) 지급, 그 id를 `questsClaimed`에(결정 ②). `canClaimDaily` = 그런 퀘스트가 하나라도 있음.
6. **출석** (B8, `meta.attendance`) — `attendance(state, tables, now) → AttendanceView{day 1~7, claimedToday, rewards[7]}`.
   - `ClaimAttendance`: 오늘 안 받았으면 `attendanceDay + 1`일차 보상 지급, `attendanceClaimed = true`. 7일차 다음은 1일차로(빠져도 초기화 없음).
   - 보상 `meta.attendance.rewards`: 젬 20·20·30·30·40·50, 7일차 영웅 확정 소환 1회 즉시(결정 ③).
7. **다음 목표** (B1) `NextGoal? nextGoal(state, tables)` → `{kind, id?, remaining, progress 0~1}`, 남은 양이 가장 작은 것 하나:
   - shipTier(다음 배 등급까지 스테이지), partMilestone(25레벨 도약까지 가장 가까운 부위 레벨), collection(다음 도감 보너스까지 선원 수), rebirth(환생 해금 스테이지까지).
   - ‘가장 가까움’은 진행률(progress)이 가장 큰 것. 같으면 위 순서.
8. **도감 보너스** (B9) `collectionBonus(state, tables) → {owned, total(40), attackBonus, nextAt}`, `attackBonus = floor(owned / every) × attackBonus(0.03)`.
   전투 피해 % 보너스 합에 넣는 것은 전투 레인(4.8 ‘마지막 합’).
9. **튜토리얼** (B10, 설계서 4.12) — `tutorialStep` 1~6, 끝·건너뜀 = null. 판정:

   | 단계 | 넘어가는 조건 | 누가 |
   | --- | --- | --- |
   | 1 | `TutorialAck(1)` (첫 15초 연출 넘기기) | UI |
   | 2 | 대포 Lv3 이상 | 코어(경제, 강화 처리 때) |
   | 3 | 스테이지 3 보스 실패 후 강화 2번 + `ChallengeBoss` → 보스 처치(bestStage ≥ 4) | 코어. ‘일부러 실패’는 전투 — 요청서 `economy-tutorial-boss` |
   | 4 | `TutorialAck(4)` (소환 결과 닫기). 이 단계에서 첫 10연 무료(이미 구현) | UI |
   | 5 | `MergeAllCards` 1번 | 코어(경제) |
   | 6 | `TutorialAck(6)` → null | UI |

   `SkipTutorial` → null. 단계와 다른 `TutorialAck(n)`은 무시. `OpSetTutorial(step)`은 그대로 설정.
10. **운영자**: `OpSpawnChest`(한도·튜토리얼 무시하고 지금 띄움), `OpGrantTailwind`, `OpSetTutorial`.

## 수용 기준 (Given / When / Then)
1. Given 튜토리얼 끝, 플레이 180초 When 틱 Then 상자 등장 + `ChestSpawned`, 40초 뒤 가라앉음.
2. Given 튜토리얼 중 When 600초 Then 상자 없음.
3. Given 상자 떠 있음 When `TapChest` Then 골드 += `chestReward`, `ChestOpened`, 상자 없음, ads.chest +1.
4. Given 오늘 상자 10번 When 240초 Then 상자 없음.
5. Given 광고 오늘 25회 When `GrantAdReward(tailwind)` Then 변화 없음.
6. Given 순풍 3시간 50분 남음 When 순풍 광고 Then 남은 시간 = 4시간(상한).
7. Given 날짜 바뀜 When 틱 Then 퀘스트·광고·받음 초기화, attendanceDay 유지.
8. Given 강화 30회·소환 1 끝(광고·처치 미완) When `ClaimDaily` Then 젬 +20, 다시 받기 불가, 나머지는 끝나면 받기 가능.
9. Given 출석 3일차까지 받음, 이틀 빠짐 When `ClaimAttendance` Then 4일차 보상(초기화 없음), 같은 날 두 번 불가.
10. Given 도감 12명 Then attackBonus 0.06, nextAt 15.
11. Given 스테이지 27 Then nextGoal = shipTier(30) remaining 3 (다른 목표보다 가까우면).
12. Given tutorialStep 2 When 대포 Lv3 강화 Then 3. Given 5 When MergeAllCards Then 6. Given 4 When TutorialAck(5) Then 4 그대로.
13. Given 튜토리얼 1 When SkipTutorial Then null.

## 문구 (ko / en)
코어·함수만. 화면 문구는 ui 레인(`ui.`·`op.`)과 econ 레인 키 없음.

## 운영자 모드에서 불러보는 법
`OpSpawnChest` → 상자, `OpGrantTailwind(30분)` → 순풍, `OpSetTutorial(3)` → 3단계, `OpAdvanceClock(24시간)` 뒤 틱 → 날짜 초기화(시계 포트가 앞서야 함 — 앱 운영자 시계).

## 결정 (2026-10-14, 사용자 → S1 경유)
- ① 상자 광고: 골드 ×5 또는 젬 30 중 선택 — `GrantAdReward(placement, choice: 'gold'|'gems')` (main c691a83)
- ② 일일 퀘스트: 퀘스트마다 젬 10
- ③ 출석: 젬 20·20·30·30·40·50, 7일차 영웅 확정 소환 1회
- ④ 복귀당 1회: `GameState.lastOfflineGold`(세이브 밖) — ClaimOffline 때 채우고 ×2 광고로 받으면 지움
- 튜토리얼 3단계 보스 실패는 전투(waves.json `tutorialFailStage`·`tutorialFailHpMultiplier`)
