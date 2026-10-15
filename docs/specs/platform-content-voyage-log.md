# 기획: 무료 항해 일지 (28일 시즌 패스, 결제 없음)

- 상태: 초안 (2026-10-15, S5) · 개요 `platform-content-overview.md` (우선순위 4 — 다른 3개가 XP 출처·보상을 준다)
- 한 줄: 28일마다 새 '항해 일지'. **평소처럼 놀면** 쌓이는 항해 XP로 30칸을 채우며 무료 보상을 받고, 원하면 칸마다 광고로 추가 보상. 마지막 칸은 그 시즌의 **새 의상(첫 등장)**.
- 피로 규칙과의 약속(개요 1절):
  - 새 할 일을 만들지 않는다 — XP는 이미 하는 행동(스테이지·보스·일일 퀘스트·현상금·출석)에서만.
  - **놓쳐도 사라지지 않는다** — 시즌이 끝날 때 안 받은 무료 보상은 자동 지급, 광고 칸은 다음 시즌 첫 7일까지 '지난 일지'에서 받기.
  - 의상은 '한정'이 아니라 **첫 등장**: 2시즌 뒤부터 일지 마지막 '보물 상자'에서 지난 의상이 다시 나온다.
  - 평소 플레이(하루 20분 안팎)면 **21일**에 30칸을 채우게 맞춘다(7일 여유). 카운트다운은 남은 '일수'만 작게(초 단위 없음).

## 1. 규칙
1. 시즌: `voyage_log.json`의 `seasons[]`(시작 날짜 UTC, 의상 id). 현재 시즌 = 시작 날짜 ≤ 오늘(현지)인 마지막 항목. 시즌 길이 `seasonDays`(28).
2. XP 출처(`xp`): 스테이지 첫 클리어 +`stageClear`(2) · 보스 처치 +`bossClear`(5) · 일일 퀘스트 받기 +`dailyQuest`(25) · 출석 받기 +`attendance`(20) · 현상금 성공·소탕 1장당 +`bounty`(15) · 환생 +`rebirth`(50).
3. 칸: 30칸, 칸마다 필요한 누적 XP `levels[i].xp`. 칸마다 **무료 보상**(받기)과 **광고 보상**(광고 1회 = 그 칸).
4. 30칸 다 채운 뒤: '보물 상자' 칸 반복 — `chestXp`(600) 모을 때마다 상자 1개(젬·선물·카드, 2시즌 뒤부터 지난 의상 포함).
5. 시즌이 바뀌는 첫 틱: 안 받은 무료 보상 **자동 지급**(묶어서 한 번, 상단 토스트 '지난 일지 보상을 받았어요'), 광고 칸 목록은 '지난 일지'로 7일 보관, XP 0으로 새 시즌.

## 2. 테이블 — `packages/game_data/tables/voyage_log.json` (economy)
```json
{
  "seasonDays": 28, "pastSeasonAdDays": 7, "chestXp": 600, "returnSkinsAfterSeasons": 2,
  "xp": {"stageClear": 2, "bossClear": 5, "dailyQuest": 25, "attendance": 20, "bounty": 15, "rebirth": 50},
  "seasons": [{"id": "s1", "start": "2026-12-01", "skin": "turtle_storm_coat", "nameKey": "logSeason1"}],
  "levels": [
    {"xp": 100,  "free": {"gems": 20},              "ad": {"gifts": {"fresh_fish": 1}}},
    {"xp": 220,  "free": {"gold": "stage"},         "ad": {"gems": 10}},
    "… 30칸 …",
    {"xp": 9000, "free": {"skin": "season"},        "ad": {"summon": 1, "minRarity": "hero"}}
  ],
  "chest": [{"weight": 50, "gems": 20}, {"weight": 30, "gifts": {"shell_charm": 2}}, {"weight": 15, "cards": 3}, {"weight": 5, "pastSkin": true}]
}
```
- `gold: "stage"` = 그 시점 스테이지 기준 골드 꾸러미(경제가 계산, 환생 직후에도 쓸모 있게).
- 균형(초기값): 하루 XP ≈ 퀘스트 100 + 출석 20 + 보스 ~60 + 현상금 45 ≈ **225** → 21일 ≈ 4,700. 마지막 칸 XP는 economy가 sim으로 맞춘다(위 9000은 자리표시).
- 무료 칸 젬 합계는 시즌당 **≤ 600**(하루 ≈ 21) — 개요 '하루 젬 ≤ 140'에 포함해 sim.

## 3. 세이브 (다음 버전)
```json
"voyageLog": {"season": "s1", "xp": 1530, "free": [1, 2, 3], "ad": [1], "chests": 0,
              "past": {"season": "s0", "ad": [4, 5, 9], "until": "2026-12-08"}}
```
- 마이그레이션: 현재 시즌·XP 0. 시즌 시작 전(표에 지난 시즌 없음)이면 `voyageLog` 비활성(UI 숨김).

## 4. 명령 · 이벤트
- `ClaimLogReward(level)` — 무료 칸, XP 충분·미수령.
- `GrantAdReward(AdPlacement.voyageLogAd, level)` — 광고 본 뒤 그 칸 광고 보상(지난 일지 칸도 같은 명령, `past: true`). `ads.json`에 `{"id": "voyageLogAd", "dailyLimit": 5}`.
- `ClaimLogChest()` — 30칸 뒤 상자.
- 이벤트: `LogXpGained(source, amount)`(UI 막대 애니용, 묶어서) · `LogLevelReached(level)` · `LogRewardClaimed(level, track, reward)` · `LogSeasonRolled(from, to, autoGranted)`.

## 5. UI 화면 (ui)
1. **상단 바 퀘스트 시트 3번째 구역 '항해 일지'**(일일 | 업적 | 일지): 위 = 시즌 이름·남은 일수·의상 미리보기(마지막 칸) / 가운데 = 가로 스크롤 30칸(칸 = 무료 위·광고 아래 2단, 받을 수 있는 칸 반짝) / 아래 = XP 막대 '다음 칸까지 140'.
2. 칸 누르기 → 보상 받기(무료) / 광고 보기(광고 칸, 광고 준비 안 되면 숨김 — 설계서 4.6 규칙).
3. '지난 일지' 줄(7일 동안만): 받을 광고 칸 수 + [열기].
4. 빨간 점: 퀘스트 아이콘 하나에 합침 — 무료 칸 받을 것이 있을 때만(광고 칸은 점 안 켬).
5. 처음 시즌이 열릴 때: 팝업 없이 퀘스트 아이콘 점 + 시트 안 '새 일지' 띠.

## 6. 렌더 · 아트
- 시즌 의상: 시즌마다 1명분(초상 + 전장 그림 2장) — `crew-bond`의 의상 규격.
- 칸 아이콘은 기존 UI 아이콘(젬·선물·카드·상자). 새 그림: 일지 표지 1장(양피지 책, 16px 격자 ×N).

## 7. 수용 기준
1. Given 일일 퀘스트 1개 받기 When 처리 Then `voyageLog.xp` +25, `LogXpGained(dailyQuest, 25)`.
2. Given xp 100 When `ClaimLogReward(1)` Then 젬 +20, 다시 → 거절. xp 99면 거절.
3. Given 광고 칸 1 When `GrantAdReward(voyageLogAd, 1)`(광고 완료) Then 선물 +1, 같은 날 5회 넘으면 거절.
4. Given 시즌 s1에서 무료 칸 2·3 미수령 When 현지 날짜가 s2 시작일 Then 2·3 보상 자동 지급, `LogSeasonRolled(s1, s2, [2,3])`, xp 0, `past.until` = +7일.
5. Given past 칸 남음 When 7일 지남 Then past 비움(무료 보상은 이미 지급돼 손실 없음).
6. Given 30칸 완료 When xp +600 Then 상자 1개 받기 가능. `returnSkinsAfterSeasons` 이후 시즌에서만 상자에 지난 의상.
7. Given 시계를 앞으로 돌림(운영자 OpAdvanceClock) When 시즌 경계 Then 4와 같음(테스트 가능).
8. 골든: 일지 구역 ko/en, 30칸 스크롤, 384·360dp 넘침 없음.

## 8. 레인 분담
| 레인 | 할 일 |
| --- | --- |
| economy | `voyage_log.json`, XP 집계 연결(퀘스트·출석·보스·현상금·환생), 시즌 경계·자동 지급, 상자 결정론, 광고 장치, sim(21일 완료·젬 상한) |
| ui | 퀘스트 시트 일지 구역, 30칸 스크롤, 지난 일지, 점 합치기 |
| render/art | 시즌 의상(시즌마다 2장), 일지 표지 |
| platform | Analytics `log_level`·`log_claim`(track), 스토어 문구 '무료 항해 일지' 한 줄 |
| S1 | 계약(`AdPlacement.voyageLogAd`·명령 2·이벤트 4·세이브), 시즌 표 관리(시작 날짜) |

## 9. 열린 질문
- 첫 시즌 시작일(출시일 기준)과 의상 주인공 — 사용자 결정.
- 시즌 표를 앱 업데이트 없이 늘리려면 서버가 필요 → 1차는 **앱에 4시즌분(112일)을 미리** 넣고 업데이트마다 추가.
