# 기획: 업적·칭호 + 주말 보너스 해역

- 상태: 초안 (2026-10-15, S5) · 개요 `platform-content-overview.md` (우선순위 1)
- 피로 규칙: 업적은 **평소 플레이로 저절로** 쌓인다(새 할 일 없음). 주말은 **보너스만** — 전용 보상·임무·순위 없음.

## A. 업적·칭호

### 규칙
1. 엔진이 평생 누적 통계 `stats`를 센다(환생해도 유지). 업적은 통계가 목표치에 닿으면 **받을 수 있음** 상태가 되고, 받기는 사람이 누른다(젬 + 칭호).
2. 업적마다 단계(동·은·금·전설 …). 앞 단계를 받아야 다음 단계가 보인다(목록이 한 번에 길어지지 않게).
3. 칭호는 꾸미기 전용(능력치 없음). 설정 화면 프로필 줄과 (2차) 랭킹 이름 옆에 보인다. 하나만 고른다.
4. 광고 시청 횟수·접속 일수 같은 **강요형 업적은 만들지 않는다**.

### 테이블 — `packages/game_data/tables/achievements.json` (economy)
```json
{
  "achievements": [
    {"id": "kills",    "stat": "kills",      "nameKey": "achKills",    "tiers": [{"target": 1000, "gems": 20}, {"target": 50000, "gems": 40}, {"target": 1000000, "gems": 80, "title": "titleSeaSweeper"}]},
    {"id": "bosses",   "stat": "bossesCleared", "nameKey": "achBosses", "tiers": [{"target": 10, "gems": 20}, {"target": 100, "gems": 40}, {"target": 1000, "gems": 80, "title": "titleBossHunter"}]},
    {"id": "stage",    "stat": "bestStage",  "nameKey": "achStage",    "tiers": [{"target": 50, "gems": 30}, {"target": 150, "gems": 60}, {"target": 300, "gems": 120, "title": "titleGhostSeaCaptain"}]},
    {"id": "summons",  "stat": "summons",    "nameKey": "achSummons",  "tiers": [{"target": 10, "gems": 10}, {"target": 100, "gems": 30}, {"target": 500, "gems": 60, "title": "titleRecruiter"}]},
    {"id": "rebirths", "stat": "rebirths",   "nameKey": "achRebirths", "tiers": [{"target": 1, "gems": 30}, {"target": 10, "gems": 60}, {"target": 50, "gems": 120, "title": "titleMapReader"}]},
    {"id": "crews",    "stat": "crewsOwned", "nameKey": "achCrews",    "tiers": [{"target": 10, "gems": 20}, {"target": 25, "gems": 50}, {"target": 40, "gems": 150, "title": "titleFullCrew"}]},
    {"id": "upgrades", "stat": "upgrades",   "nameKey": "achUpgrades", "tiers": [{"target": 500, "gems": 10}, {"target": 10000, "gems": 30}, {"target": 100000, "gems": 60, "title": "titleShipwright"}]},
    {"id": "bounty",   "stat": "bountyClears", "nameKey": "achBounty", "tiers": [{"target": 10, "gems": 20}, {"target": 100, "gems": 50, "title": "titleBountyHunter"}]}
  ],
  "titles": [{"id": "titleSeaSweeper", "nameKey": "titleSeaSweeper"}, "…"]
}
```
- 젬 총합(전부 받으면) ≈ 1,300 — 수개월에 걸쳐 나온다. economy가 sim으로 '첫 주 받는 젬 ≤ 150' 확인.
- `bounty`는 현상금(`platform-content-bounty.md`)이 들어올 때 추가.

### 세이브 (다음 버전)
- `stats`: `{kills: int, bossesCleared: int, summons: int, rebirths: int, upgrades: int, bountyClears: int}` — **평생**, 환생에도 유지. `bestStage`·`crewsOwned`는 기존 값(`progress.bestStage`의 평생 최고 `stats.bestStageEver`, `collection.length`)에서 읽는다.
- `achievements`: `{id: 받은 단계 수}` · `title`: 고른 칭호 id 또는 null.
- 마이그레이션: 기존 세이브는 `stats` 0부터(과거 수치는 모름) — 단 `bestStageEver = progress.bestStage`, `summons = summonsTotal`로 채운다.

### 명령 · 이벤트
- `ClaimAchievement(id)` → 다음 단계가 달성돼 있으면 젬 지급 + 칭호 해금, 아니면 무시(로그).
- `SetTitle(titleId?)` → 해금된 칭호만.
- 이벤트: `AchievementReady(id, tier)`(목표 도달 순간 1회, 빨간 점·작은 토스트용) · `AchievementClaimed(id, tier, gems)`.

### UI (ui)
- 상단 바 퀘스트 시트에 구역 추가: **일일 | 업적** 2칸 세그먼트(시트 높이 그대로). 업적 줄 = 이름·진행 막대·보상(젬 아이콘+숫자)·받기 버튼.
- 설정 화면 맨 위 '칭호' 줄 → 해금 칭호 목록 시트.
- 빨간 점: 퀘스트 아이콘(이미 있음)에 받을 업적이 있을 때도 켬. 토스트: 업적 도달 시 화면 위 2초 작은 띠("업적: 바다 청소부 Ⅱ") — 팝업 아님.
- **태블릿(800×1280, dpr 2)**: 퀘스트 시트는 폭 최대 560dp 가운데(양옆 바다 배경), 업적 줄은 2열 대신 1열 유지(읽기 흐름). 주말 칩은 상단 바 그대로.

### 수용 기준
1. Given 처치 999 When 1마리 더 처치 Then `stats.kills` 1000, `AchievementReady(kills, 1)` 1회.
2. Given 1단계 받을 수 있음 When `ClaimAchievement(kills)` Then 젬 +20, 2단계 목표가 보임. 같은 명령 다시 → 변화 없음.
3. Given 환생 When 환생 완료 Then `stats` 그대로.
4. Given 칭호 미해금 When `SetTitle` Then 무시.
5. Given v5 세이브 When 불러오기 Then `stats.summons = summonsTotal`, 업적 0단계.
6. 골든: 업적 구역 ko/en, 384dp에서 넘침 없음.

## B. 주말 보너스 해역

### 규칙
1. **기기 현지 토·일**(Clock 현지 요일, 일일 초기화와 같은 기준)에 자동으로 켜진다. 켜는 데 할 일 없음.
2. 효과: 처치·보스 **골드 ×2**, 보물상자 등장 확률 ×2, 무리마다 **황금 게**가 확률로 1마리 섞임(처치 시 젬 1~3, 결정론 난수).
3. 순풍(광고 ×2)과 곱해진다. 오프라인 보상은 **주말 배수 없음**(벽시계 조작 유인 줄이기).
4. 전용 보상·임무·순위·카운트다운 없음. 월요일 0시에 조용히 꺼진다.

### 테이블 — `meta.json` 아래 `weekend` (economy)
```json
"weekend": {"days": [6, 7], "goldMultiplier": 2.0, "chestRateMultiplier": 2.0,
            "special": {"kind": "gold_crab", "chancePerWave": 0.15, "gemsMin": 1, "gemsMax": 3}}
```
- `regions.json` 적 목록과 별개 — 황금 게는 모든 해역에 같은 그림. 하루 젬 상한 효과 ≈ 무리 수 × 0.15 × 2 → sim으로 '주말 하루 +20~40 젬' 맞춤.

### 세이브 · 명령 · 이벤트
- 세이브 없음(현지 요일로 계산). 통계에 `stats.goldCrabs`만(업적 후보).
- 명령 없음. 이벤트: `WeekendBonus(active: bool)` — 상태가 바뀔 때 1회(전장 축제 하늘, 상단 바 칩).

### UI · 렌더
- ui: 상단 바 순풍 칩 옆 **'주말 ×2'** 칩(아이콘 + 글자). 누르면 한 줄 설명 시트. 팝업 없음.
- render: 하늘 색조 축제 톤(`fx_map.weekendTint`), 황금 게 스프라이트(`enemies/gold_crab.png`, art) + 처치 시 젬 반짝임.

### 수용 기준
1. Given 현지 토요일 When 무리 처치 Then 골드 = 평일 × 2 (순풍 켜면 × 4).
2. Given 같은 rngSeed·같은 시각 When 두 번 시뮬레이션 Then 황금 게 위치·젬 같음(결정론).
3. Given 일요일 23:59 → 월요일 00:00 When 틱 Then `WeekendBonus(false)` 1회, 배수 1.
4. Given 오프라인 10시간(주말 포함) When 복귀 Then 오프라인 골드 = 평일 계산.

## 레인 분담
| 레인 | 할 일 |
| --- | --- |
| economy | `achievements.json`·`meta.weekend` 표, `stats` 집계 위치, 젬 sim, 마이그레이션 |
| battle | 황금 게 스폰(결정론), 주말 골드 배수 적용 지점 |
| ui | 퀘스트 시트 업적 구역, 칭호 시트, 주말 칩, 토스트 |
| render/art | 황금 게 그림·연출, 축제 하늘 색조 |
| platform | Analytics `achievement_claim`, 스토어 문구에 '주말 2배' 한 줄 |
| S1 | 계약(명령·이벤트·세이브 v6) 리뷰·머지 |
